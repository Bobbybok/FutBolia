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
import { actorCanManageTournaments } from '../../common/staff-access';
import { TeamsService } from '../teams/teams.service';
import { TeamMember } from '../teams/entities/team-member.entity';

@Injectable()
export class TournamentsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly config: ConfigService,
    private readonly teams: TeamsService,
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

    const startersCount = dto.startersCount ?? 5;
    const substitutesCount = startersCount;

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
        joinCode: null,
        joinCodeEnabled: false,
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
      tournament.substitutesCount = dto.startersCount;
    }
    if (dto.rulesText !== undefined) {
      tournament.rulesText = dto.rulesText?.trim() || null;
    }
    if (dto.mode !== undefined) tournament.mode = dto.mode;
    if (dto.status !== undefined) tournament.status = dto.status;

    if (dto.visibility !== undefined) {
      tournament.visibility = dto.visibility;
      if (dto.visibility === TournamentVisibility.PUBLIC) {
        tournament.joinCodeEnabled = false;
        tournament.joinCode = null;
      }
    }

    if (dto.joinCodeEnabled !== undefined) {
      // Codes d'accès obsolètes : on ignore / force off.
      tournament.joinCodeEnabled = false;
      tournament.joinCode = null;
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
    await this.requireOrganizer(id, userId);
    throw new BadRequestException(
      'Les codes d’accès sont remplacés par les invitations d’amis',
    );
  }

  async join(
    id: string,
    userId: string,
    options?: { code?: string; viaInvite?: boolean },
  ) {
    await this.requireVerifiedEmail(userId);

    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }

    if (tournament.status !== TournamentStatus.REGISTRATION_OPEN) {
      throw new BadRequestException('Les inscriptions sont fermées');
    }

    if (tournament.visibility === TournamentVisibility.PRIVATE) {
      if (!options?.viaInvite) {
        throw new ForbiddenException(
          'Ce tournoi est privé : demande une invitation à l’organisateur',
        );
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

  async leave(id: string, userId: string) {
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    if (tournament.createdById === userId) {
      throw new BadRequestException(
        'L’organisateur ne peut pas quitter : supprime le tournoi à la place',
      );
    }
    if (
      tournament.status === TournamentStatus.FINISHED ||
      tournament.status === TournamentStatus.CANCELLED
    ) {
      throw new BadRequestException('Impossible de quitter ce tournoi');
    }

    const membership = await this.members.findOne({
      where: { tournamentId: id, userId },
    });
    if (!membership) {
      throw new BadRequestException('Tu n’es pas inscrit à ce tournoi');
    }

    await this.teams.detachUserFromTournament(id, userId);
    await this.members.delete({ id: membership.id });
    return { success: true };
  }

  async addMember(id: string, actorId: string, userId: string) {
    await this.requireOrganizer(id, actorId);
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    if (
      tournament.status === TournamentStatus.FINISHED ||
      tournament.status === TournamentStatus.CANCELLED
    ) {
      throw new BadRequestException('Impossible d’ajouter un participant');
    }

    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.deletedAt) {
      throw new NotFoundException('Utilisateur introuvable');
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
    return this.listMembers(id, actorId);
  }

  async kickMember(id: string, actorId: string, userId: string) {
    await this.requireOrganizer(id, actorId);
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    if (tournament.createdById === userId) {
      throw new BadRequestException(
        'Impossible de retirer le créateur du tournoi',
      );
    }
    if (userId === actorId && tournament.createdById === actorId) {
      throw new BadRequestException('Tu ne peux pas te retirer');
    }

    const membership = await this.members.findOne({
      where: { tournamentId: id, userId },
    });
    if (!membership) {
      throw new NotFoundException('Ce joueur n’est pas inscrit');
    }

    await this.teams.detachUserFromTournament(id, userId);
    await this.members.delete({ id: membership.id });
    return this.listMembers(id, actorId);
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
      const staff = await actorCanManageTournaments(this.db, viewerId);
      if (!member && !staff) {
        throw new ForbiddenException("Vous n'êtes pas membre de ce tournoi privé");
      }
    }

    const rows = await this.members.find({
      where: { tournamentId: id },
      relations: { user: { profile: true } },
      order: { joinedAt: 'ASC' },
    });

    const teamRows = await this.db
      .getRepository(TeamMember)
      .createQueryBuilder('tm')
      .innerJoinAndSelect('tm.team', 'team')
      .innerJoinAndSelect('tm.user', 'user')
      .leftJoinAndSelect('user.profile', 'profile')
      .where('team.tournament_id = :tournamentId', { tournamentId: id })
      .getMany();

    const teamByUser = new Map(
      teamRows.map((row) => [
        row.userId,
        {
          teamId: row.teamId,
          teamName: row.team?.name ?? null,
          slot: row.slot,
          position: row.position,
          isCaptain: row.team?.captainId === row.userId,
        },
      ]),
    );

    return rows.map((m) => {
      const team = teamByUser.get(m.userId);
      return {
        id: m.id,
        role: m.role,
        joinedAt: m.joinedAt,
        teamId: team?.teamId ?? null,
        teamName: team?.teamName ?? null,
        slot: team?.slot ?? null,
        position: team?.position ?? null,
        isCaptain: team?.isCaptain ?? false,
        user: {
          id: m.user.id,
          pseudo: m.user.profile?.pseudo ?? null,
          avatarUrl: m.user.profile?.avatarUrl ?? null,
          role: toPlatformRole(m.user.globalRole),
        },
      };
    });
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

    if (
      !membership &&
      tournament.createdById !== userId &&
      !(await actorCanManageTournaments(this.db, userId))
    ) {
      throw new ForbiddenException("Seul l'organisateur peut modifier ce tournoi");
    }

    return tournament;
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

    const staff = viewerId
      ? await actorCanManageTournaments(this.db, viewerId)
      : false;

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
      substitutesCount: tournament.startersCount,
      rulesText: tournament.rulesText,
      mode: tournament.mode,
      visibility: tournament.visibility,
      status: tournament.status,
      joinCodeEnabled: false,
      membersCount,
      myRole: membership?.role ?? null,
      isOrganizer: Boolean(isOrganizer),
      canManage: Boolean(isOrganizer || staff),
      canCreateTeam: Boolean(
        (isOrganizer || staff) ||
          (membership != null &&
            tournament.mode !== TournamentMode.SELECTION),
      ),
      canAccessInterTeamChat: false,
      createdById: tournament.createdById,
      createdAt: tournament.createdAt,
    };
  }
}
