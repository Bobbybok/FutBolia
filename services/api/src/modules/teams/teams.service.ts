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
  FifaPosition,
  TeamMemberSlot,
  TeamStatus,
  toPlatformRole,
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
import { AssignTeamDto } from './dto/assign-team.dto';
import { actorCanManageTournaments } from '../../common/staff-access';
import { RealtimeDispatchService } from '../realtime/services/realtime-dispatch.service';
import { RealtimeEvents } from '../realtime/realtime-events';

type RosterActor = {
  team: Team;
  staff: boolean;
  organizer: boolean;
  captain: boolean;
  selector: boolean;
  canBypassValidation: boolean;
};

@Injectable()
export class TeamsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly realtime: RealtimeDispatchService,
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
    await this.ensureTeamColumns();
    const tournament = await this.requireTournament(tournamentId);
    if (!(await actorCanManageTournaments(this.db, actorId))) {
      await this.requireTournamentMember(tournamentId, actorId);
    }
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

    const organizerOrStaff = await this.actorIsOrganizerOrStaff(
      tournamentId,
      actorId,
    );

    if (tournament.mode === TournamentMode.SELECTION) {
      await this.requireOrganizer(tournamentId, actorId);
      if (dto.selectorId) {
        await this.requireTournamentMember(tournamentId, dto.selectorId);
        await this.assertSelectorAvailable(tournamentId, dto.selectorId);
      }

      const team = await this.persistTeam({
        tournamentId,
        name: dto.name.trim(),
        logoUrl: dto.logoUrl?.trim() || null,
        createdById: actorId,
        captainId: null,
        selectorId: dto.selectorId ?? null,
        status: TeamStatus.FORMING,
      });

      if (dto.selectorId) {
        await this.ensureSelectorRole(tournamentId, dto.selectorId);
      }

      return this.getById(team.id, actorId);
    }

    const existingTeam = await this.findUserTeamInTournament(
      tournamentId,
      actorId,
    );
    if (existingTeam && !organizerOrStaff) {
      throw new ConflictException(
        'Vous appartenez déjà à une équipe dans ce tournoi',
      );
    }

    const tournamentMembership = await this.tournamentMembers.findOne({
      where: { tournamentId, userId: actorId },
    });
    const joinAsCaptain = !existingTeam && (tournamentMembership != null || !organizerOrStaff);

    const team = await this.persistTeam({
      tournamentId,
      name: dto.name.trim(),
      logoUrl: dto.logoUrl?.trim() || null,
      createdById: actorId,
      captainId: joinAsCaptain ? actorId : null,
      selectorId: null,
      status: TeamStatus.FORMING,
    });

    if (joinAsCaptain) {
      await this.teamMembers.save(
        this.teamMembers.create({
          teamId: team.id,
          userId: actorId,
          slot: TeamMemberSlot.STARTER,
          position: null,
        }),
      );
      await this.refreshTeamStatus(team.id);
    }

    return this.getById(team.id, actorId);
  }

  async listByTournament(tournamentId: string, viewerId?: string) {
    await this.ensureTeamColumns();
    await this.requireTournament(tournamentId);
    const rows = await this.teams.find({
      where: { tournamentId },
      order: { createdAt: 'ASC' },
    });
    return Promise.all(rows.map((team) => this.toPublic(team, viewerId)));
  }

  async getById(teamId: string, viewerId?: string) {
    await this.ensureTeamColumns();
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    return this.toPublic(team, viewerId, true);
  }

  async update(teamId: string, actorId: string, dto: UpdateTeamDto) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    await this.requireOrganizer(team.tournamentId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
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

  async removeTeam(teamId: string, actorId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    await this.requireOrganizer(team.tournamentId, actorId);
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);

    await this.teamMembers.delete({ teamId });
    await this.teams.remove(team);
    return { success: true, message: 'Équipe supprimée', id: teamId };
  }

  async addMember(teamId: string, actorId: string, dto: AddTeamMemberDto) {
    return this.assignPlayer(actorId, {
      userId: dto.userId,
      teamId,
      slot: dto.slot,
      position: dto.position,
    });
  }

  async updateMember(
    teamId: string,
    memberUserId: string,
    actorId: string,
    dto: UpdateTeamMemberDto,
  ) {
    const ctx = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(ctx.team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    const member = await this.teamMembers.findOne({
      where: { teamId, userId: memberUserId },
    });
    if (!member) {
      throw new NotFoundException("Membre d'équipe introuvable");
    }

    if (dto.slot != null && member.slot !== dto.slot) {
      await this.assertSlotCapacity(teamId, tournament, dto.slot, memberUserId);
      member.slot = dto.slot;
    }
    if (dto.position !== undefined) {
      member.position = dto.position ?? null;
    }
    await this.teamMembers.save(member);

    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async removeMember(teamId: string, memberUserId: string, actorId: string) {
    return this.assignPlayer(actorId, {
      userId: memberUserId,
      teamId: null,
    });
  }

  async leave(teamId: string, actorId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    const tournament = await this.requireTournament(team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    if (team.status === TeamStatus.VALIDATED) {
      throw new BadRequestException(
        'Cette équipe est validée. Demandez à l’organisateur de te retirer.',
      );
    }

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
    const ctx = await this.requireTeamManager(teamId, actorId);
    if (!ctx.captain && !ctx.organizer && !ctx.staff) {
      throw new ForbiddenException(
        'Seul le capitaine, l’organisateur ou un admin peut transférer le rôle',
      );
    }
    const tournament = await this.requireTournament(ctx.team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
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

    ctx.team.captainId = newCaptainId;
    await this.teams.save(ctx.team);
    await this.refreshTeamStatus(teamId);
    await this.notifyCaptain(ctx.team, newCaptainId, actorId);
    return this.getById(teamId, actorId);
  }

  async toggleSlot(teamId: string, memberUserId: string, actorId: string) {
    const ctx = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(ctx.team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);

    const member = await this.teamMembers.findOne({
      where: { teamId, userId: memberUserId },
    });
    if (!member) {
      throw new NotFoundException("Membre d'équipe introuvable");
    }

    const next =
      member.slot === TeamMemberSlot.STARTER
        ? TeamMemberSlot.SUBSTITUTE
        : TeamMemberSlot.STARTER;

    try {
      await this.assertSlotCapacity(teamId, tournament, next, memberUserId);
      member.slot = next;
      await this.teamMembers.save(member);
    } catch {
      const other = await this.teamMembers.findOne({
        where: { teamId, slot: next },
        order: { joinedAt: 'DESC' },
      });
      if (!other || other.userId === memberUserId) {
        throw new BadRequestException('Impossible d’échanger ce poste');
      }
      const previous = member.slot;
      member.slot = next;
      other.slot = previous;
      await this.teamMembers.save([member, other]);
    }

    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  async assignPlayer(
    actorId: string,
    dto: AssignTeamDto,
    tournamentId?: string,
  ) {
    if (dto.teamId) {
      return this.moveToTeam(actorId, dto.userId, dto.teamId, {
        slot: dto.slot,
        position: dto.position,
      });
    }
    return this.unassignFromTeam(actorId, dto.userId, tournamentId);
  }

  async detachUserFromTournament(tournamentId: string, userId: string) {
    const membership = await this.findUserTeamInTournament(tournamentId, userId);
    if (!membership) return;
    const team = await this.teams.findOne({ where: { id: membership.teamId } });
    if (!team) {
      await this.teamMembers.delete({ id: membership.id });
      return;
    }
    await this.teamMembers.delete({ id: membership.id });
    if (team.captainId === userId) {
      await this.promoteCaptain(team);
    }
    await this.refreshTeamStatus(team.id);
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
        `L’effectif n’est pas complet (${tournament.startersCount} titulaires et ${this.benchSize(tournament)} remplaçant(s) requis)`,
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

    if (team.status === TeamStatus.VALIDATED) {
      team.status = TeamStatus.FORMING;
      await this.teams.save(team);
    }
    await this.refreshTeamStatus(teamId);
    return this.getById(teamId, actorId);
  }

  private async moveToTeam(
    actorId: string,
    userId: string,
    teamId: string,
    opts: { slot?: TeamMemberSlot; position?: FifaPosition | null },
  ) {
    const ctx = await this.requireTeamManager(teamId, actorId);
    const tournament = await this.requireTournament(ctx.team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    await this.requireTournamentMember(tournament.id, userId);

    const current = await this.findUserTeamRow(tournament.id, userId);
    if (current && current.teamId !== teamId) {
      if (!ctx.canBypassValidation) {
        throw new ForbiddenException(
          'Seul l’organisateur peut déplacer un joueur déjà dans une autre équipe',
        );
      }
      const previous = await this.teams.findOne({
        where: { id: current.teamId },
      });
      await this.teamMembers.delete({ id: current.id });
      if (previous && previous.captainId === userId) {
        await this.promoteCaptain(previous);
      }
      if (previous) {
        await this.refreshTeamStatus(previous.id);
      }
    }

    let member = await this.teamMembers.findOne({
      where: { teamId, userId },
    });
    const slot =
      opts.slot ?? member?.slot ?? (await this.firstAvailableSlot(teamId, tournament, userId));
    if (!member || member.slot !== slot) {
      await this.assertSlotCapacity(teamId, tournament, slot, userId);
    }

    if (!member) {
      member = this.teamMembers.create({
        teamId,
        userId,
        slot,
        position: opts.position ?? null,
      });
    } else {
      member.slot = slot;
      if (opts.position !== undefined) {
        member.position = opts.position ?? null;
      }
    }
    await this.teamMembers.save(member);
    await this.refreshTeamStatus(teamId);
    await this.notifyAssigned(ctx.team, userId, actorId);
    return this.getById(teamId, actorId);
  }

  private async unassignFromTeam(
    actorId: string,
    userId: string,
    tournamentId?: string,
  ) {
    let memberships = await this.teamMembers.find({ where: { userId } });
    if (tournamentId) {
      const inTournament: TeamMember[] = [];
      for (const row of memberships) {
        const team = await this.teams.findOne({ where: { id: row.teamId } });
        if (team?.tournamentId === tournamentId) inTournament.push(row);
      }
      memberships = inTournament;
    }
    if (memberships.length === 0) {
      throw new NotFoundException("Ce joueur n'est dans aucune équipe");
    }

    let target = memberships[0];
    if (memberships.length > 1) {
      // Prefer a team the actor can manage.
      for (const row of memberships) {
        const team = await this.teams.findOne({ where: { id: row.teamId } });
        if (!team) continue;
        const can =
          team.captainId === actorId ||
          (await this.actorIsOrganizerOrStaff(team.tournamentId, actorId));
        if (can) {
          target = row;
          break;
        }
      }
    }

    const ctx = await this.requireTeamManager(target.teamId, actorId);
    const tournament = await this.requireTournament(ctx.team.tournamentId);
    this.assertTournamentAllowsTeamEdits(tournament);
    if (!ctx.canBypassValidation && ctx.team.captainId === userId) {
      throw new BadRequestException(
        'Impossible de retirer le capitaine. Transférez d’abord le rôle.',
      );
    }

    await this.teamMembers.delete({ id: target.id });
    if (ctx.team.captainId === userId) {
      await this.promoteCaptain(ctx.team);
    }
    await this.refreshTeamStatus(ctx.team.id);
    return this.getById(ctx.team.id, actorId);
  }

  private async firstAvailableSlot(
    teamId: string,
    tournament: Tournament,
    excludeUserId?: string,
  ) {
    try {
      await this.assertSlotCapacity(
        teamId,
        tournament,
        TeamMemberSlot.STARTER,
        excludeUserId,
      );
      return TeamMemberSlot.STARTER;
    } catch {
      await this.assertSlotCapacity(
        teamId,
        tournament,
        TeamMemberSlot.SUBSTITUTE,
        excludeUserId,
      );
      return TeamMemberSlot.SUBSTITUTE;
    }
  }

  private async promoteCaptain(team: Team) {
    const members = await this.teamMembers.find({
      where: { teamId: team.id },
      order: { joinedAt: 'ASC' },
    });
    const next =
      members.find((m) => m.slot === TeamMemberSlot.STARTER) ?? members[0];
    team.captainId = next?.userId ?? null;
    await this.teams.save(team);
    if (team.captainId) {
      await this.notifyCaptain(team, team.captainId, null);
    }
  }

  private async notifyAssigned(team: Team, userId: string, actorId: string) {
    if (userId === actorId) return;
    const tournament = await this.requireTournament(team.tournamentId);
    await this.realtime.notifyUser({
      userId,
      event: RealtimeEvents.teamAssigned,
      payload: {
        teamId: team.id,
        tournamentId: team.tournamentId,
        teamName: team.name,
      },
      push: {
        title: tournament.name,
        body: `Tu es dans l’équipe ${team.name}`,
        data: {
          type: 'team_assigned',
          teamId: team.id,
          tournamentId: team.tournamentId,
        },
      },
    });
  }

  private async notifyCaptain(
    team: Team,
    userId: string,
    actorId: string | null,
  ) {
    if (actorId && userId === actorId) return;
    const tournament = await this.requireTournament(team.tournamentId);
    await this.realtime.notifyUser({
      userId,
      event: RealtimeEvents.teamCaptain,
      payload: {
        teamId: team.id,
        tournamentId: team.tournamentId,
        teamName: team.name,
      },
      push: {
        title: tournament.name,
        body: `Tu es capitaine de ${team.name}`,
        data: {
          type: 'team_captain',
          teamId: team.id,
          tournamentId: team.tournamentId,
        },
      },
    });
  }

  private async refreshTeamStatus(teamId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      return;
    }
    const tournament = await this.requireTournament(team.tournamentId);
    const starters = await this.teamMembers.count({
      where: { teamId, slot: TeamMemberSlot.STARTER },
    });
    const substitutes = await this.teamMembers.count({
      where: { teamId, slot: TeamMemberSlot.SUBSTITUTE },
    });
    const complete =
      starters >= tournament.startersCount &&
      substitutes >= this.benchSize(tournament);

    if (team.status === TeamStatus.VALIDATED) {
      if (complete) return;
      team.status = TeamStatus.FORMING;
      await this.teams.save(team);
      return;
    }

    team.status = complete ? TeamStatus.COMPLETE : TeamStatus.FORMING;
    await this.teams.save(team);
  }

  private benchSize(tournament: Tournament) {
    return tournament.startersCount;
  }

  private teamColumnsReady = false;

  private async ensureTeamColumns() {
    if (this.teamColumnsReady) return;
    await this.db.query(`
      ALTER TABLE teams
        ADD COLUMN IF NOT EXISTS selector_id uuid
    `);
    await this.db.query(`
      ALTER TABLE team_members
        ADD COLUMN IF NOT EXISTS position varchar(8)
    `);
    this.teamColumnsReady = true;
  }

  private async persistTeam(data: Partial<Team>): Promise<Team> {
    const save = () => this.teams.save(this.teams.create(data));
    try {
      return await save();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (!/selector_id|does not exist/i.test(msg)) {
        throw err;
      }
      this.teamColumnsReady = false;
      await this.ensureTeamColumns();
      return save();
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
    if (await this.actorIsOrganizerOrStaff(tournamentId, userId)) {
      return;
    }
    throw new ForbiddenException(
      "Seul l'organisateur peut effectuer cette action",
    );
  }

  private async actorIsOrganizerOrStaff(tournamentId: string, userId: string) {
    if (await actorCanManageTournaments(this.db, userId)) {
      return true;
    }
    const tournament = await this.requireTournament(tournamentId);
    if (tournament.createdById === userId) {
      return true;
    }
    const membership = await this.tournamentMembers.findOne({
      where: {
        tournamentId,
        userId,
        role: TournamentMemberRole.ORGANIZER,
      },
    });
    return membership != null;
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

  private async requireTeamManager(
    teamId: string,
    actorId: string,
  ): Promise<RosterActor> {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }

    const tournamentMembership = await this.tournamentMembers.findOne({
      where: { tournamentId: team.tournamentId, userId: actorId },
    });
    const tournament = await this.requireTournament(team.tournamentId);

    const organizer =
      tournamentMembership?.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === actorId;
    const captain = team.captainId === actorId;
    const selector = team.selectorId === actorId;
    const staff = await actorCanManageTournaments(this.db, actorId);

    if (!organizer && !captain && !selector && !staff) {
      throw new ForbiddenException(
        "Seuls l'organisateur, le capitaine ou le sélectionneur peuvent gérer cette équipe",
      );
    }

    return {
      team,
      staff,
      organizer,
      captain,
      selector,
      canBypassValidation: organizer || staff,
    };
  }

  private async findUserTeamInTournament(tournamentId: string, userId: string) {
    return this.findUserTeamRow(tournamentId, userId);
  }

  private async findUserTeamRow(tournamentId: string, userId: string) {
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
        : this.benchSize(tournament);

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
    const tournament = await this.requireTournament(team.tournamentId);
    const organizerOrStaff =
      viewerId != null
        ? await this.actorIsOrganizerOrStaff(team.tournamentId, viewerId)
        : false;

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
      startersMax: tournament.startersCount,
      substitutesMax: this.benchSize(tournament),
      starters: starters.map((m) => this.mapMember(m, team.captainId)),
      substitutes: substitutes.map((m) => this.mapMember(m, team.captainId)),
      members: members.map((m) => this.mapMember(m, team.captainId)),
      myMembership:
        viewerId == null
          ? null
          : members.find((m) => m.userId === viewerId)?.slot ?? null,
      isCaptain: viewerId != null && team.captainId === viewerId,
      isSelector: viewerId != null && team.selectorId === viewerId,
      isMember: viewerId != null && members.some((m) => m.userId === viewerId),
      canManageRoster:
        organizerOrStaff ||
        (viewerId != null &&
          (team.captainId === viewerId || team.selectorId === viewerId)),
      canTransferCaptain:
        organizerOrStaff ||
        (viewerId != null && team.captainId === viewerId),
      canEditTeam: organizerOrStaff,
    };
  }

  private mapMember(member: TeamMember, captainId: string | null) {
    return {
      userId: member.userId,
      slot: member.slot,
      position: member.position,
      isCaptain: member.userId === captainId,
      joinedAt: member.joinedAt,
      pseudo: member.user?.profile?.pseudo ?? null,
      avatarUrl: member.user?.profile?.avatarUrl ?? null,
      role: toPlatformRole(member.user?.globalRole),
    };
  }
}
