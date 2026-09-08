import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  TeamMemberSlot,
  TeamStatus,
  TournamentMemberRole,
  TournamentMode,
  TournamentStatus,
} from '../../common/enums';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { Team } from './entities/team.entity';
import { TeamMember } from './entities/team-member.entity';
import { CreateTeamDto } from './dto/create-team.dto';
import { UpdateTeamDto } from './dto/update-team.dto';
import { AddTeamMemberDto } from './dto/add-team-member.dto';
import { UpdateTeamMemberDto } from './dto/update-team-member.dto';

@Injectable()
export class TeamsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get teams(): Repository<Team> {
    return this.db.getRepository(Team);
  }

  private get teamMembers(): Repository<TeamMember> {
    return this.db.getRepository(TeamMember);
  }

  private get tournaments(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get tournamentMembers(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  async create(tournamentId: string, actorId: string, dto: CreateTeamDto) {
    const tournament = await this.requireTournament(tournamentId);
    await this.requireTournamentMember(tournamentId, actorId);
    this.assertTournamentAllowsTeamEdits(tournament);

    const teamCount = await this.teams.count({ where: { tournamentId } });
    if (teamCount >= tournament.maxTeams) {
      throw new BadRequestException("Nombre maximum d'équipes atteint");
    }

    const duplicateName = await this.teams.findOne({
      where: { tournamentId, name: dto.name.trim() },
    });
    if (duplicateName) {
      throw new ConflictException("Nom d'équipe déjà utilisé dans ce tournoi");
    }

    if (tournament.mode === TournamentMode.SELECTION) {
      await this.requireOrganizer(tournamentId, actorId);
      if (dto.selectorId) {
        await this.requireTournamentMember(tournamentId, dto.selectorId);
        await this.assertSelectorAvailable(tournamentId, dto.selectorId);
      }

      const team = await this.teams.save(
        this.teams.create({
          tournamentId,
          name: dto.name.trim(),
          logoUrl: dto.logoUrl?.trim() || null,
          createdById: actorId,
          captainId: null,
          selectorId: dto.selectorId ?? null,
          status: TeamStatus.FORMING,
        }),
      );

      if (dto.selectorId) {
        await this.ensureSelectorRole(tournamentId, dto.selectorId);
      }

      return this.getById(team.id, actorId);
    }

    // Mode classique : le créateur rejoint comme capitaine / titulaire.
    const existingTeam = await this.findUserTeamInTournament(
      tournamentId,
      actorId,
    );
    if (existingTeam) {
      throw new ConflictException(
        'Vous appartenez déjà à une équipe dans ce tournoi',
      );
    }

    const team = await this.teams.save(
      this.teams.create({
        tournamentId,
        name: dto.name.trim(),
        logoUrl: dto.logoUrl?.trim() || null,
        createdById: actorId,
        captainId: actorId,
        status: TeamStatus.FORMING,
      }),
    );

    await this.teamMembers.save(
      this.teamMembers.create({
        teamId: team.id,
        userId: actorId,
        slot: TeamMemberSlot.STARTER,
      }),
    );

    await this.refreshTeamStatus(team.id);
    return this.getById(team.id, actorId);
  }

  async listByTournament(tournamentId: string, viewerId?: string) {
    await this.requireTournament(tournamentId);
    const rows = await this.teams.find({
      where: { tournamentId },
      order: { createdAt: 'ASC' },
    });
    return Promise.all(rows.map((team) => this.toPublic(team, viewerId)));
  }

  async getById(teamId: string, viewerId?: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    return this.toPublic(team, viewerId, true);
  }

  async update(teamId: string, actorId: string, dto: UpdateTeamDto) {
    const team = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    this.assertTeamNotValidated(team);

    if (dto.name !== undefined) {
      const name = dto.name.trim();
      const duplicate = await this.teams.findOne({
        where: { tournamentId: team.tournamentId, name },
      });
      if (duplicate && duplicate.id !== team.id) {
        throw new ConflictException("Nom d'équipe déjà utilisé dans ce tournoi");
      }
      team.name = name;
    }
    if (dto.logoUrl !== undefined) {
      team.logoUrl = dto.logoUrl?.trim() || null;
    }

    await this.teams.save(team);
    return this.getById(teamId, actorId);
  }

  async addMember(teamId: string, actorId: string, dto: AddTeamMemberDto) {
    const team = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    this.assertTeamNotValidated(team);

    await this.requireTournamentMember(tournament.id, dto.userId);

    const alreadyInTeam = await this.findUserTeamInTournament(
      tournament.id,
      dto.userId,
    );
    if (alreadyInTeam) {
      throw new ConflictException(
        'Le joueur appartient déjà à une équipe dans ce tournoi',
      );
    }

    const slot = dto.slot ?? TeamMemberSlot.STARTER;
    await this.assertSlotCapacity(team.id, tournament, slot);

    await this.teamMembers.save(
      this.teamMembers.create({
        teamId: team.id,
        userId: dto.userId,
        slot,
      }),
    );

    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async updateMember(
    teamId: string,
    memberUserId: string,
    actorId: string,
    dto: UpdateTeamMemberDto,
  ) {
    const team = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    this.assertTeamNotValidated(team);

    const member = await this.teamMembers.findOne({
      where: { teamId, userId: memberUserId },
    });
    if (!member) {
      throw new NotFoundException("Membre d'équipe introuvable");
    }

    if (member.slot !== dto.slot) {
      await this.assertSlotCapacity(teamId, tournament, dto.slot, memberUserId);
      member.slot = dto.slot;
      await this.teamMembers.save(member);
    }

    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async removeMember(teamId: string, memberUserId: string, actorId: string) {
    const team = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    this.assertTeamNotValidated(team);

    const member = await this.teamMembers.findOne({
      where: { teamId, userId: memberUserId },
    });
    if (!member) {
      throw new NotFoundException("Membre d'équipe introuvable");
    }

    if (team.captainId === memberUserId) {
      throw new BadRequestException(
        'Impossible de retirer le capitaine. Transférez d’abord le rôle.',
      );
    }

    await this.teamMembers.delete({ id: member.id });
    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async leave(teamId: string, actorId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    this.assertTeamNotValidated(team);

    const member = await this.teamMembers.findOne({
      where: { teamId, userId: actorId },
    });
    if (!member) {
      throw new BadRequestException('Vous n’êtes pas membre de cette équipe');
    }
    if (team.captainId === actorId) {
      throw new BadRequestException(
        'Le capitaine doit transférer le rôle avant de quitter l’équipe',
      );
    }

    await this.teamMembers.delete({ id: member.id });
    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async setCaptain(teamId: string, actorId: string, newCaptainId: string) {
    const team = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    this.assertTeamNotValidated(team);

    const member = await this.teamMembers.findOne({
      where: { teamId, userId: newCaptainId },
    });
    if (!member) {
      throw new BadRequestException(
        "Le capitaine doit être un membre de l'équipe",
      );
    }

    if (member.slot !== TeamMemberSlot.STARTER) {
      await this.assertSlotCapacity(
        teamId,
        tournament,
        TeamMemberSlot.STARTER,
        newCaptainId,
      );
      member.slot = TeamMemberSlot.STARTER;
      await this.teamMembers.save(member);
    }

    team.captainId = newCaptainId;
    await this.teams.save(team);
    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async validateTeam(teamId: string, actorId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    await this.requireOrganizer(team.tournamentId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);

    await this.refreshTeamStatus(teamId);
    const refreshed = await this.teams.findOneByOrFail({ id: teamId });
    if (refreshed.status !== TeamStatus.COMPLETE) {
      throw new BadRequestException(
        `L’effectif n’est pas complet (${tournament.startersCount} titulaires et ${tournament.substitutesCount} remplaçant(s) requis)`,
      );
    }

    refreshed.status = TeamStatus.VALIDATED;
    await this.teams.save(refreshed);
    return this.getById(teamId, actorId);
  }

  async unvalidateTeam(teamId: string, actorId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    await this.requireOrganizer(team.tournamentId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);

    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  private async refreshTeamStatus(teamId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team || team.status === TeamStatus.VALIDATED) {
      return;
    }
    const tournament = await this.requireTournament(team.tournamentId);
    const starters = await this.teamMembers.count({
      where: { teamId, slot: TeamMemberSlot.STARTER },
    });
    const substitutes = await this.teamMembers.count({
      where: { teamId, slot: TeamMemberSlot.SUBSTITUTE },
    });

    team.status =
      starters >= tournament.startersCount &&
      substitutes >= tournament.substitutesCount
        ? TeamStatus.COMPLETE
        : TeamStatus.FORMING;
    await this.teams.save(team);
  }

  private assertTeamNotValidated(team: Team) {
    if (team.status === TeamStatus.VALIDATED) {
      throw new BadRequestException(
        'Cette équipe est validée. Demandez à l’organisateur de la rouvrir.',
      );
    }
  }

  private async requireTournament(tournamentId: string) {
    const tournament = await this.tournaments.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    return tournament;
  }

  private assertTournamentAllowsTeamEdits(tournament: Tournament) {
    if (
      tournament.status === TournamentStatus.FINISHED ||
      tournament.status === TournamentStatus.CANCELLED
    ) {
      throw new BadRequestException(
        'Impossible de modifier les équipes d’un tournoi terminé ou annulé',
      );
    }
  }

  private async requireTournamentMember(tournamentId: string, userId: string) {
    const membership = await this.tournamentMembers.findOne({
      where: { tournamentId, userId },
    });
    if (!membership) {
      throw new ForbiddenException(
        "L'utilisateur n'est pas participant au tournoi",
      );
    }
    return membership;
  }

  private async requireOrganizer(tournamentId: string, userId: string) {
    const tournament = await this.requireTournament(tournamentId);
    const membership = await this.tournamentMembers.findOne({
      where: {
        tournamentId,
        userId,
        role: TournamentMemberRole.ORGANIZER,
      },
    });
    if (!membership && tournament.createdById !== userId) {
      throw new ForbiddenException(
        "Seul l'organisateur peut effectuer cette action",
      );
    }
  }

  private async ensureSelectorRole(tournamentId: string, userId: string) {
    const membership = await this.tournamentMembers.findOne({
      where: { tournamentId, userId },
    });
    if (!membership) {
      throw new ForbiddenException('Le sélectionneur doit être participant');
    }
    if (membership.role === TournamentMemberRole.PLAYER) {
      membership.role = TournamentMemberRole.SELECTOR;
      await this.tournamentMembers.save(membership);
    }
  }

  private async assertSelectorAvailable(
    tournamentId: string,
    selectorId: string,
    excludeTeamId?: string,
  ) {
    const qb = this.teams
      .createQueryBuilder('t')
      .where('t.tournament_id = :tournamentId', { tournamentId })
      .andWhere('t.selector_id = :selectorId', { selectorId });
    if (excludeTeamId) {
      qb.andWhere('t.id != :excludeTeamId', { excludeTeamId });
    }
    const existing = await qb.getOne();
    if (existing) {
      throw new ConflictException(
        'Ce joueur est déjà sélectionneur d’une autre équipe dans ce tournoi',
      );
    }
  }

  private async requireTeamManager(teamId: string, actorId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }

    const tournamentMembership = await this.tournamentMembers.findOne({
      where: { tournamentId: team.tournamentId, userId: actorId },
    });

    const isOrganizer =
      tournamentMembership?.role === TournamentMemberRole.ORGANIZER;
    const isCaptain = team.captainId === actorId;
    const isSelector = team.selectorId === actorId;

    if (!isOrganizer && !isCaptain && !isSelector) {
      throw new ForbiddenException(
        "Seuls l'organisateur, le capitaine ou le sélectionneur peuvent gérer cette équipe",
      );
    }

    return team;
  }

  private async findUserTeamInTournament(tournamentId: string, userId: string) {
    return this.teamMembers
      .createQueryBuilder('tm')
      .innerJoin(Team, 't', 't.id = tm.team_id')
      .where('t.tournament_id = :tournamentId', { tournamentId })
      .andWhere('tm.user_id = :userId', { userId })
      .getOne();
  }

  private async assertSlotCapacity(
    teamId: string,
    tournament: Tournament,
    slot: TeamMemberSlot,
    excludeUserId?: string,
  ) {
    const qb = this.teamMembers
      .createQueryBuilder('tm')
      .where('tm.team_id = :teamId', { teamId })
      .andWhere('tm.slot = :slot', { slot });

    if (excludeUserId) {
      qb.andWhere('tm.user_id != :excludeUserId', { excludeUserId });
    }

    const count = await qb.getCount();
    const max =
      slot === TeamMemberSlot.STARTER
        ? tournament.startersCount
        : tournament.substitutesCount;

    if (count >= max) {
      throw new BadRequestException(
        slot === TeamMemberSlot.STARTER
          ? `Limite de titulaires atteinte (${max})`
          : `Limite de remplaçants atteinte (${max})`,
      );
    }
  }

  private async toPublic(
    team: Team,
    viewerId?: string,
    withMembers = true,
  ) {
    const members = withMembers
      ? await this.teamMembers.find({
          where: { teamId: team.id },
          relations: { user: { profile: true } },
          order: { joinedAt: 'ASC' },
        })
      : [];

    const starters = members.filter((m) => m.slot === TeamMemberSlot.STARTER);
    const substitutes = members.filter(
      (m) => m.slot === TeamMemberSlot.SUBSTITUTE,
    );

    return {
      id: team.id,
      tournamentId: team.tournamentId,
      name: team.name,
      logoUrl: team.logoUrl,
      status: team.status,
      captainId: team.captainId,
      selectorId: team.selectorId,
      createdById: team.createdById,
      createdAt: team.createdAt,
      membersCount: members.length,
      startersCount: starters.length,
      substitutesCount: substitutes.length,
      starters: starters.map((m) => this.mapMember(m, team.captainId)),
      substitutes: substitutes.map((m) => this.mapMember(m, team.captainId)),
      myMembership:
        viewerId == null
          ? null
          : members.find((m) => m.userId === viewerId)?.slot ?? null,
      isCaptain: viewerId != null && team.captainId === viewerId,
      isSelector: viewerId != null && team.selectorId === viewerId,
    };
  }

  private mapMember(member: TeamMember, captainId: string | null) {
    return {
      userId: member.userId,
      slot: member.slot,
      isCaptain: member.userId === captainId,
      joinedAt: member.joinedAt,
      pseudo: member.user?.profile?.pseudo ?? null,
      avatarUrl: member.user?.profile?.avatarUrl ?? null,
    };
  }
}
