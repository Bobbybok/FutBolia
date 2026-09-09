import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, In, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  PickupMatchSide,
  PickupMatchStatus,
  toPlatformRole,
  TournamentVisibility,
} from '../../common/enums';
import { User } from '../users/entities/user.entity';
import { PickupMatch } from './entities/pickup-match.entity';
import { PickupMatchMember } from './entities/pickup-match-member.entity';
import { CreatePickupMatchDto } from './dto/create-pickup-match.dto';
import { ScorePickupMatchDto } from './dto/score-pickup-match.dto';

@Injectable()
export class PickupMatchesService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get matches(): Repository<PickupMatch> {
    return this.db.getRepository(PickupMatch);
  }

  private get members(): Repository<PickupMatchMember> {
    return this.db.getRepository(PickupMatchMember);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  async create(userId: string, dto: CreatePickupMatchDto) {
    await this.requireVerifiedEmail(userId);

    const visibility = dto.visibility ?? TournamentVisibility.PUBLIC;

    const match = await this.matches.save(
      this.matches.create({
        playersPerTeam: dto.playersPerTeam,
        scheduledAt: new Date(dto.scheduledAt),
        location: dto.location.trim(),
        visibility,
        joinCode: null,
        status: PickupMatchStatus.OPEN,
        createdById: userId,
      }),
    );

    await this.members.save(
      this.members.create({
        matchId: match.id,
        userId,
        side: PickupMatchSide.HOME,
      }),
    );

    return this.getById(match.id, userId);
  }

  async list(params: { mine?: boolean; userId?: string }) {
    if (params.mine) {
      if (!params.userId) {
        throw new ForbiddenException('Authentification requise');
      }
      const rows = await this.matches
        .createQueryBuilder('m')
        .innerJoin(PickupMatchMember, 'mem', 'mem.match_id = m.id')
        .where('mem.user_id = :userId', { userId: params.userId })
        .andWhere('m.status NOT IN (:...excluded)', {
          excluded: [PickupMatchStatus.CANCELLED],
        })
        .orderBy('m.scheduled_at', 'ASC')
        .getMany();
      return Promise.all(rows.map((m) => this.toPublic(m, params.userId)));
    }

    const rows = await this.matches.find({
      where: {
        visibility: TournamentVisibility.PUBLIC,
        status: In([PickupMatchStatus.OPEN, PickupMatchStatus.FULL]),
      },
      order: { scheduledAt: 'ASC' },
      take: 50,
    });

    return Promise.all(rows.map((m) => this.toPublic(m, params.userId)));
  }

  async getById(id: string, viewerId?: string) {
    const match = await this.matches.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    return this.toPublic(match, viewerId, true);
  }

  async join(
    id: string,
    userId: string,
    options?: { code?: string; viaInvite?: boolean },
  ) {
    await this.requireVerifiedEmail(userId);

    const match = await this.matches.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }

    if (
      match.status !== PickupMatchStatus.OPEN &&
      match.status !== PickupMatchStatus.FULL
    ) {
      throw new BadRequestException('Ce match n’accepte plus d’inscriptions');
    }

    if (match.status === PickupMatchStatus.FULL) {
      throw new BadRequestException('Ce match est complet');
    }

    if (match.visibility === TournamentVisibility.PRIVATE) {
      if (!options?.viaInvite) {
        throw new ForbiddenException(
          'Ce match est privé : demande une invitation à l’hôte',
        );
      }
    }

    const existing = await this.members.findOne({
      where: { matchId: id, userId },
    });
    if (existing) {
      throw new ConflictException('Déjà inscrit à ce match');
    }

    const capacity = match.playersPerTeam * 2;
    const membersCount = await this.members.count({ where: { matchId: id } });
    if (membersCount >= capacity) {
      match.status = PickupMatchStatus.FULL;
      await this.matches.save(match);
      throw new BadRequestException('Ce match est complet');
    }

    const homeCount = await this.members.count({
      where: { matchId: id, side: PickupMatchSide.HOME },
    });
    const side =
      homeCount < match.playersPerTeam
        ? PickupMatchSide.HOME
        : PickupMatchSide.AWAY;

    await this.members.save(
      this.members.create({
        matchId: id,
        userId,
        side,
      }),
    );

    if (membersCount + 1 >= capacity) {
      match.status = PickupMatchStatus.FULL;
      await this.matches.save(match);
    }

    return this.getById(id, userId);
  }

  async leave(id: string, userId: string) {
    const match = await this.matches.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }

    if (
      match.status === PickupMatchStatus.FINISHED ||
      match.status === PickupMatchStatus.CANCELLED
    ) {
      throw new BadRequestException('Impossible de quitter ce match');
    }

    if (match.createdById === userId) {
      throw new BadRequestException(
        'L’hôte ne peut pas quitter : annule le match à la place',
      );
    }

    const member = await this.members.findOne({
      where: { matchId: id, userId },
    });
    if (!member) {
      throw new NotFoundException('Tu n’es pas inscrit à ce match');
    }

    await this.members.delete({ id: member.id });

    if (match.status === PickupMatchStatus.FULL) {
      match.status = PickupMatchStatus.OPEN;
      await this.matches.save(match);
    }

    return this.getById(id, userId);
  }

  async score(id: string, userId: string, dto: ScorePickupMatchDto) {
    const match = await this.requireHost(id, userId);

    if (match.status === PickupMatchStatus.CANCELLED) {
      throw new BadRequestException('Ce match est annulé');
    }
    if (match.status === PickupMatchStatus.FINISHED) {
      throw new BadRequestException('Le score est déjà saisi');
    }

    match.homeScore = dto.homeScore;
    match.awayScore = dto.awayScore;
    match.status = PickupMatchStatus.FINISHED;
    await this.matches.save(match);

    return this.getById(id, userId);
  }

  async cancel(id: string, userId: string) {
    const match = await this.requireHost(id, userId);

    if (match.status === PickupMatchStatus.FINISHED) {
      throw new BadRequestException('Un match terminé ne peut pas être annulé');
    }
    if (match.status === PickupMatchStatus.CANCELLED) {
      throw new BadRequestException('Ce match est déjà annulé');
    }

    match.status = PickupMatchStatus.CANCELLED;
    match.homeScore = null;
    match.awayScore = null;
    await this.matches.save(match);

    return this.getById(id, userId);
  }

  private async requireVerifiedEmail(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    if (!user.emailVerifiedAt) {
      throw new ForbiddenException(
        "L'e-mail doit être vérifié avant de rejoindre ou de créer un match",
      );
    }
  }

  private async requireHost(id: string, userId: string) {
    const match = await this.matches.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    if (match.createdById !== userId) {
      throw new ForbiddenException('Seul l’hôte peut effectuer cette action');
    }
    return match;
  }

  private async toPublic(
    match: PickupMatch,
    viewerId?: string,
    includeMembers = false,
  ) {
    const membership = viewerId
      ? await this.members.findOne({
          where: { matchId: match.id, userId: viewerId },
        })
      : null;

    const isHost = match.createdById === viewerId;
    const capacity = match.playersPerTeam * 2;
    const membersCount = await this.members.count({
      where: { matchId: match.id },
    });

    let members:
      | Array<{
          id: string;
          side: PickupMatchSide;
          joinedAt: Date;
          user: {
            id: string;
            pseudo: string | null;
            avatarUrl: string | null;
            role: string;
          };
        }>
      | undefined;

    if (includeMembers) {
      const rows = await this.members.find({
        where: { matchId: match.id },
        relations: { user: { profile: true } },
        order: { joinedAt: 'ASC' },
      });
      members = rows.map((m) => ({
        id: m.id,
        side: m.side,
        joinedAt: m.joinedAt,
        user: {
          id: m.user.id,
          pseudo: m.user.profile?.pseudo ?? null,
          avatarUrl: m.user.profile?.avatarUrl ?? null,
          role: toPlatformRole(m.user.globalRole),
        },
      }));
    }

    return {
      id: match.id,
      playersPerTeam: match.playersPerTeam,
      capacity,
      scheduledAt: match.scheduledAt,
      location: match.location,
      visibility: match.visibility,
      status: match.status,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      membersCount,
      mySide: membership?.side ?? null,
      isHost,
      isMember: membership != null,
      createdById: match.createdById,
      createdAt: match.createdAt,
      members,
    };
  }
}
