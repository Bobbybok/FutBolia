import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import { DataSource, ILike, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  toPlatformRole,
  TournamentMemberRole,
  TournamentMode,
  TournamentStatus,
  TournamentVisibility,
} from '../../common/enums';
import { User } from '../users/entities/user.entity';
import { Tournament } from './entities/tournament.entity';
import { TournamentMember } from './entities/tournament-member.entity';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { UpdateTournamentDto } from './dto/update-tournament.dto';

@Injectable()
export class TournamentsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get tournaments(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get members(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  async create(userId: string, dto: CreateTournamentDto) {
    await this.requireVerifiedEmail(userId);

    const visibility = dto.visibility ?? TournamentVisibility.PUBLIC;
    const joinCode =
      visibility === TournamentVisibility.PRIVATE
        ? await this.generateUniqueJoinCode()
        : null;

    const startersCount = dto.startersCount ?? 5;
    const substitutesCount = dto.substitutesCount ?? 2;

    const tournament = await this.tournaments.save(
      this.tournaments.create({
        name: dto.name.trim(),
        description: dto.description?.trim() || null,
        startsAt: new Date(dto.startsAt),
        location: dto.location.trim(),
        maxTeams: dto.maxTeams,
        startersCount,
        substitutesCount,
        rulesText: dto.rulesText?.trim() || null,
        mode: dto.mode ?? TournamentMode.CLASSIC,
        visibility,
        joinCode,
        joinCodeEnabled: visibility === TournamentVisibility.PRIVATE,
        status: TournamentStatus.REGISTRATION_OPEN,
        createdById: userId,
      }),
    );

    await this.members.save(
      this.members.create({
        tournamentId: tournament.id,
        userId,
        role: TournamentMemberRole.ORGANIZER,
      }),
    );

    return this.getById(tournament.id, userId);
  }

  async list(params: {
    q?: string;
    mine?: boolean;
    userId?: string;
  }) {
    if (params.mine) {
      if (!params.userId) {
        throw new ForbiddenException('Authentification requise');
      }
      const rows = await this.tournaments
        .createQueryBuilder('t')
        .innerJoin(TournamentMember, 'm', 'm.tournament_id = t.id')
        .where('m.user_id = :userId', { userId: params.userId })
        .orderBy('t.starts_at', 'ASC')
        .getMany();
      return Promise.all(rows.map((t) => this.toPublic(t, params.userId)));
    }

    const where = params.q
      ? [
          {
            visibility: TournamentVisibility.PUBLIC,
            name: ILike(`%${params.q}%`),
          },
          {
            visibility: TournamentVisibility.PUBLIC,
            location: ILike(`%${params.q}%`),
          },
        ]
      : { visibility: TournamentVisibility.PUBLIC };

    const rows = await this.tournaments.find({
      where,
      order: { startsAt: 'ASC' },
      take: 50,
    });

    return Promise.all(rows.map((t) => this.toPublic(t, params.userId)));
  }

  async getById(id: string, viewerId?: string) {
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }

    if (
      tournament.visibility === TournamentVisibility.PRIVATE &&
      viewerId
    ) {
      const member = await this.members.findOne({
        where: { tournamentId: id, userId: viewerId },
      });
      if (!member && tournament.createdById !== viewerId) {
        // Private details still visible if you know the id after join attempt flow;
        // hide join code unless organizer.
      }
    }

    return this.toPublic(tournament, viewerId, true);
  }

  async update(id: string, userId: string, dto: UpdateTournamentDto) {
    const tournament = await this.requireOrganizer(id, userId);

    if (dto.name !== undefined) tournament.name = dto.name.trim();
    if (dto.description !== undefined) {
      tournament.description = dto.description?.trim() || null;
    }
    if (dto.startsAt !== undefined) tournament.startsAt = new Date(dto.startsAt);
    if (dto.location !== undefined) tournament.location = dto.location.trim();
    if (dto.maxTeams !== undefined) tournament.maxTeams = dto.maxTeams;
    if (dto.startersCount !== undefined) {
      tournament.startersCount = dto.startersCount;
    }
    if (dto.substitutesCount !== undefined) {
      tournament.substitutesCount = dto.substitutesCount;
    }
    if (dto.rulesText !== undefined) {
      tournament.rulesText = dto.rulesText?.trim() || null;
    }
    if (dto.mode !== undefined) tournament.mode = dto.mode;
    if (dto.status !== undefined) tournament.status = dto.status;

    if (dto.visibility !== undefined) {
      tournament.visibility = dto.visibility;
      if (
        dto.visibility === TournamentVisibility.PRIVATE &&
        !tournament.joinCode
      ) {
        tournament.joinCode = await this.generateUniqueJoinCode();
        tournament.joinCodeEnabled = true;
      }
      if (dto.visibility === TournamentVisibility.PUBLIC) {
        tournament.joinCodeEnabled = false;
      }
    }

    if (dto.joinCodeEnabled !== undefined) {
      if (tournament.visibility !== TournamentVisibility.PRIVATE) {
        throw new BadRequestException(
          "Le code d'invitation s'applique uniquement aux tournois privés",
        );
      }
      tournament.joinCodeEnabled = dto.joinCodeEnabled;
      if (dto.joinCodeEnabled && !tournament.joinCode) {
        tournament.joinCode = await this.generateUniqueJoinCode();
      }
    }

    await this.tournaments.save(tournament);
    return this.getById(id, userId);
  }

  async remove(id: string, userId: string) {
    const tournament = await this.requireOrganizer(id, userId);
    await this.tournaments.remove(tournament);
    return {
      success: true,
      message: 'Tournoi supprimé',
      id,
    };
  }

  async regenerateJoinCode(id: string, userId: string) {
    const tournament = await this.requireOrganizer(id, userId);
    if (tournament.visibility !== TournamentVisibility.PRIVATE) {
      throw new BadRequestException(
        "Le code d'invitation s'applique uniquement aux tournois privés",
      );
    }
    tournament.joinCode = await this.generateUniqueJoinCode();
    tournament.joinCodeEnabled = true;
    await this.tournaments.save(tournament);
    return this.getById(id, userId);
  }

  async join(id: string, userId: string, code?: string) {
    await this.requireVerifiedEmail(userId);

    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }

    if (tournament.status !== TournamentStatus.REGISTRATION_OPEN) {
      throw new BadRequestException('Les inscriptions sont fermées');
    }

    if (tournament.visibility === TournamentVisibility.PRIVATE) {
      if (!tournament.joinCodeEnabled || !tournament.joinCode) {
        throw new ForbiddenException("Le code d'invitation est désactivé");
      }
      if (!code || code.trim().toUpperCase() !== tournament.joinCode) {
        throw new ForbiddenException("Code d'invitation invalide");
      }
    }

    const existing = await this.members.findOne({
      where: { tournamentId: id, userId },
    });
    if (existing) {
      throw new ConflictException('Déjà membre de ce tournoi');
    }

    await this.members.save(
      this.members.create({
        tournamentId: id,
        userId,
        role: TournamentMemberRole.PLAYER,
      }),
    );

    return this.getById(id, userId);
  }

  async listMembers(id: string, viewerId?: string) {
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }

    if (tournament.visibility === TournamentVisibility.PRIVATE) {
      if (!viewerId) {
        throw new ForbiddenException('Authentification requise');
      }
      const member = await this.members.findOne({
        where: { tournamentId: id, userId: viewerId },
      });
      if (!member) {
        throw new ForbiddenException("Vous n'êtes pas membre de ce tournoi privé");
      }
    }

    const rows = await this.members.find({
      where: { tournamentId: id },
      relations: { user: { profile: true } },
      order: { joinedAt: 'ASC' },
    });

    return rows.map((m) => ({
      id: m.id,
      role: m.role,
      joinedAt: m.joinedAt,
      user: {
        id: m.user.id,
        pseudo: m.user.profile?.pseudo ?? null,
        avatarUrl: m.user.profile?.avatarUrl ?? null,
        role: toPlatformRole(m.user.globalRole),
      },
    }));
  }

  private async requireVerifiedEmail(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    if (!user.emailVerifiedAt) {
      throw new ForbiddenException(
        "L'e-mail doit être vérifié avant de rejoindre ou de créer un tournoi",
      );
    }
  }

  private async requireOrganizer(id: string, userId: string) {
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }

    const membership = await this.members.findOne({
      where: {
        tournamentId: id,
        userId,
        role: TournamentMemberRole.ORGANIZER,
      },
    });

    if (!membership && tournament.createdById !== userId) {
      throw new ForbiddenException("Seul l'organisateur peut modifier ce tournoi");
    }

    return tournament;
  }

  private async generateUniqueJoinCode() {
    for (let i = 0; i < 8; i++) {
      const code = randomBytes(3).toString('hex').toUpperCase().slice(0, 6);
      const exists = await this.tournaments.findOne({
        where: { joinCode: code },
      });
      if (!exists) {
        return code;
      }
    }
    throw new BadRequestException("Impossible de générer un code d'invitation");
  }

  private async toPublic(
    tournament: Tournament,
    viewerId?: string,
    includeMembersCount = true,
  ) {
    const membership = viewerId
      ? await this.members.findOne({
          where: { tournamentId: tournament.id, userId: viewerId },
        })
      : null;

    const isOrganizer =
      membership?.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === viewerId;

    let membersCount: number | undefined;
    if (includeMembersCount) {
      membersCount = await this.members.count({
        where: { tournamentId: tournament.id },
      });
    }

    return {
      id: tournament.id,
      name: tournament.name,
      imageUrl: tournament.imageUrl,
      description: tournament.description,
      startsAt: tournament.startsAt,
      location: tournament.location,
      maxTeams: tournament.maxTeams,
      startersCount: tournament.startersCount,
      substitutesCount: tournament.substitutesCount,
      rulesText: tournament.rulesText,
      mode: tournament.mode,
      visibility: tournament.visibility,
      status: tournament.status,
      joinCodeEnabled: tournament.joinCodeEnabled,
      joinCode: isOrganizer ? tournament.joinCode : undefined,
      membersCount,
      myRole: membership?.role ?? null,
      createdById: tournament.createdById,
      createdAt: tournament.createdAt,
    };
  }
}
