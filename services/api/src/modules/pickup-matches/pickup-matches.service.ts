import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
import { AddPickupMemberDto } from './dto/add-pickup-member.dto';
import { UpdatePickupMemberDto } from './dto/update-pickup-member.dto';
import { actorCanManageTournaments } from '../../common/staff-access';
import { LiveEventsService } from '../realtime/services/live-events.service';

@Injectable()
export class PickupMatchesService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly config: ConfigService,
    private readonly live: LiveEventsService,
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
    await this.ensureSideNullable();

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
        side: null,
      }),
    );

    await this.ping(match.id, 'pickup.created');
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
    await this.ensureSideNullable();
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

    await this.members.save(
      this.members.create({
        matchId: id,
        userId,
        side: null,
      }),
    );

    if (membersCount + 1 >= capacity) {
      match.status = PickupMatchStatus.FULL;
      await this.matches.save(match);
    }

    await this.ping(id, 'pickup.member');
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

    await this.ping(id, 'pickup.member');
    return this.getById(id, userId);
  }

  async addMember(id: string, actorId: string, dto: AddPickupMemberDto) {
    await this.ensureSideNullable();
    await this.requireHost(id, actorId);
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

    const user = await this.users.findOne({ where: { id: dto.userId } });
    if (!user || user.deletedAt) {
      throw new NotFoundException('Utilisateur introuvable');
    }

    const existing = await this.members.findOne({
      where: { matchId: id, userId: dto.userId },
    });
    if (existing) {
      throw new ConflictException('Déjà inscrit à ce match');
    }

    const capacity = match.playersPerTeam * 2;
    const membersCount = await this.members.count({ where: { matchId: id } });
    if (membersCount >= capacity) {
      throw new BadRequestException('Ce match est complet');
    }

    const side = dto.side ?? null;
    if (side) {
      await this.assertSideCapacity(id, match.playersPerTeam, side);
    }
    await this.members.save(
      this.members.create({
        matchId: id,
        userId: dto.userId,
        side,
      }),
    );
    if (membersCount + 1 >= capacity) {
      match.status = PickupMatchStatus.FULL;
      await this.matches.save(match);
    }
    await this.ping(id, 'pickup.member');
    return this.getById(id, actorId);
  }

  async kickMember(id: string, actorId: string, userId: string) {
    await this.requireHost(id, actorId);
    const match = await this.matches.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    if (match.createdById === userId) {
      throw new BadRequestException('Impossible de retirer l’hôte');
    }
    const member = await this.members.findOne({
      where: { matchId: id, userId },
    });
    if (!member) {
      throw new NotFoundException('Ce joueur n’est pas inscrit');
    }
    await this.members.delete({ id: member.id });
    if (match.status === PickupMatchStatus.FULL) {
      match.status = PickupMatchStatus.OPEN;
      await this.matches.save(match);
    }
    await this.ping(id, 'pickup.member');
    return this.getById(id, actorId);
  }

  async updateMemberSide(
    id: string,
    actorId: string,
    userId: string,
    dto: UpdatePickupMemberDto,
  ) {
    await this.ensureSideNullable();
    await this.requireHost(id, actorId);
    const match = await this.matches.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    if (
      match.status === PickupMatchStatus.FINISHED ||
      match.status === PickupMatchStatus.CANCELLED
    ) {
      throw new BadRequestException('Impossible de déplacer un joueur');
    }
    const member = await this.members.findOne({
      where: { matchId: id, userId },
    });
    if (!member) {
      throw new NotFoundException('Ce joueur n’est pas inscrit');
    }
    if (member.side !== dto.side) {
      if (dto.side) {
        await this.assertSideCapacity(
          id,
          match.playersPerTeam,
          dto.side,
          userId,
        );
      }
      member.side = dto.side ?? null;
      await this.members.save(member);
    }
    await this.ping(id, 'pickup.member');
    return this.getById(id, actorId);
  }

  private async assertSideCapacity(
    matchId: string,
    playersPerTeam: number,
    side: PickupMatchSide,
    excludeUserId?: string,
  ) {
    const qb = this.members
      .createQueryBuilder('m')
      .where('m.match_id = :matchId', { matchId })
      .andWhere('m.side = :side', { side });
    if (excludeUserId) {
      qb.andWhere('m.user_id != :excludeUserId', { excludeUserId });
    }
    const count = await qb.getCount();
    if (count >= playersPerTeam) {
      throw new BadRequestException(
        side === PickupMatchSide.HOME
          ? 'Équipe A complète'
          : 'Équipe B complète',
      );
    }
  }

  async score(id: string, userId: string, dto: ScorePickupMatchDto) {
    const match = await this.requireHost(id, userId);

    if (match.status === PickupMatchStatus.CANCELLED) {
      throw new BadRequestException('Ce match est annulé');
    }
    if (match.status === PickupMatchStatus.FINISHED) {
      const staff = await actorCanManageTournaments(this.db, userId);
      if (!staff) {
        throw new BadRequestException('Le score est déjà saisi');
      }
    }

    match.homeScore = dto.homeScore;
    match.awayScore = dto.awayScore;
    match.status = PickupMatchStatus.FINISHED;
    await this.matches.save(match);

    await this.ping(id, 'pickup.score');
    return this.getById(id, userId);
  }

  async cancel(id: string, userId: string) {
    const match = await this.requireHost(id, userId);

    if (match.status === PickupMatchStatus.FINISHED) {
      const staff = await actorCanManageTournaments(this.db, userId);
      if (!staff) {
        throw new BadRequestException('Un match terminé ne peut pas être annulé');
      }
    }
    if (match.status === PickupMatchStatus.CANCELLED) {
      throw new BadRequestException('Ce match est déjà annulé');
    }

    match.status = PickupMatchStatus.CANCELLED;
    match.homeScore = null;
    match.awayScore = null;
    await this.matches.save(match);

    await this.ping(id, 'pickup.cancelled');
    return this.getById(id, userId);
  }

  async remove(id: string, userId: string) {
    const match = await this.requireHost(id, userId);
    await this.ping(id, 'pickup.deleted', { actorId: userId });
    await this.matches.remove(match);
    return { success: true, message: 'Match supprimé', id };
  }

  private ping(
    matchId: string,
    reason: string,
    extra: Record<string, unknown> = {},
  ) {
    void this.live.pickupChanged(matchId, reason, extra);
  }

  private sideNullableReady = false;

  private async ensureSideNullable() {
    if (this.sideNullableReady) return;
    await this.db.query(`
      ALTER TABLE pickup_match_members
        ALTER COLUMN side DROP NOT NULL
    `);
    this.sideNullableReady = true;
  }

  private async requireVerifiedEmail(userId: string) {
    const required =
      (this.config.get<string>('EMAIL_VERIFICATION_REQUIRED') ?? 'false')
        .toLowerCase() === 'true';
    if (!required) {
      return;
    }
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
    if (
      match.createdById !== userId &&
      !(await actorCanManageTournaments(this.db, userId))
    ) {
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
          side: PickupMatchSide | null;
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
      members = rows
        .filter((m) => m.user)
        .map((m) => ({
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
