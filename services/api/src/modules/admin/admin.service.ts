import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { DataSource, ILike, In, IsNull, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  AdminPermissionType,
  ALL_ADMIN_PERMISSIONS,
  GlobalRole,
  isPlatformAdmin,
  MatchStatus,
  PickupMatchStatus,
  ReportReasonCode,
  ReportStatus,
  ReportType,
  reportReasonLabel,
  reportReasonsFor,
  reportTypeLabel,
  TeamStatus,
  toPlatformRole,
  TournamentMemberRole,
  TournamentStatus,
  UserStatus,
} from '../../common/enums';
import { User } from '../users/entities/user.entity';
import { Profile } from '../users/entities/profile.entity';
import { AdminPermission } from './entities/admin-permission.entity';
import { AuditLog } from './entities/audit-log.entity';
import { Report } from './entities/report.entity';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { Team } from '../teams/entities/team.entity';
import { Match } from '../matches/entities/match.entity';
import { PickupMatch } from '../pickup-matches/entities/pickup-match.entity';
import { ProfileAvatar } from '../users/entities/profile-avatar.entity';
import { TournamentChatMessage } from '../chat/entities/tournament-chat-message.entity';
import { DirectMessage } from '../private-chat/entities/direct-message.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
import { AuthService } from '../auth/auth.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import {
  BanUserDto,
  CreateReportDto,
  ForceTeamStatusDto,
  PatchAdminMatchDto,
  PatchAdminPickupDto,
  PatchAdminTeamDto,
  PatchAdminUserDto,
  PatchTournamentDto,
  ResolveReportDto,
  TimeoutUserDto,
} from './dto/admin.dto';
import { serializeSportProfile, fifaToLegacyPosition } from '../users/profile-view';

@Injectable()
export class AdminService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly auth: AuthService,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  private get profiles(): Repository<Profile> {
    return this.db.getRepository(Profile);
  }

  private get permissions(): Repository<AdminPermission> {
    return this.db.getRepository(AdminPermission);
  }

  private get auditLogs(): Repository<AuditLog> {
    return this.db.getRepository(AuditLog);
  }

  private get reports(): Repository<Report> {
    return this.db.getRepository(Report);
  }

  private get tournaments(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get members(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  private get teams(): Repository<Team> {
    return this.db.getRepository(Team);
  }

  private get matches(): Repository<Match> {
    return this.db.getRepository(Match);
  }

  private get pickups(): Repository<PickupMatch> {
    return this.db.getRepository(PickupMatch);
  }

  private get avatars(): Repository<ProfileAvatar> {
    return this.db.getRepository(ProfileAvatar);
  }

  private get messages(): Repository<TournamentChatMessage> {
    return this.db.getRepository(TournamentChatMessage);
  }

  private get directMessages(): Repository<DirectMessage> {
    return this.db.getRepository(DirectMessage);
  }

  private get refreshTokens(): Repository<RefreshToken> {
    return this.db.getRepository(RefreshToken);
  }

  async listAdmins() {
    return this.listStaff(['admin', 'super_admin']);
  }

  async listModerators() {
    return this.listStaff(['moderator']);
  }

  async searchUsers(query?: string) {
    const q = query?.trim();
    const users = await this.users.find({
      relations: { profile: true },
      order: { createdAt: 'DESC' },
      take: 40,
      ...(q
        ? {
            where: [
              { email: ILike(`%${q}%`) },
              { profile: { pseudo: ILike(`%${q}%`) } },
            ],
          }
        : {}),
    });
    const permMap = await this.permissionMap(users.map((u) => u.id));
    return users.map((user) =>
      this.toListUser(user, permMap.get(user.id) ?? []),
    );
  }

  async getUser(id: string) {
    const user = await this.users.findOne({
      where: { id },
      relations: { profile: true },
    });
    if (!user?.profile) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    const permissions = await this.auth.listPermissions(id);
    const memberships = await this.members.find({
      where: { userId: id },
      relations: { tournament: true },
      order: { joinedAt: 'DESC' },
    });
    const sessions = await this.refreshTokens.count({
      where: { userId: id, revokedAt: IsNull() },
    });
    return {
      ...this.toListUser(user, permissions),
      emailVerified: Boolean(user.emailVerifiedAt),
      profile: serializeSportProfile(user.profile),
      createdAt: user.createdAt,
      activeSessions: sessions,
      tournaments: memberships.map((m) => ({
        id: m.tournamentId,
        name: m.tournament?.name ?? '',
        role: m.role,
        joinedAt: m.joinedAt,
      })),
    };
  }

  async grant(
    actor: AuthUser,
    userId: string,
    permissionList: AdminPermissionType[],
  ) {
    this.assertNotSelf(actor.id, userId);
    const unique = this.normalizePermissions(permissionList);
    const user = await this.requireUser(userId);

    user.globalRole = GlobalRole.ADMIN;
    await this.users.save(user);
    await this.replacePermissions(userId, unique, actor.id);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'grant_admin', userId, { permissions: unique });
    return this.getUser(userId);
  }

  async grantModerator(
    actor: AuthUser,
    userId: string,
    permissionList?: AdminPermissionType[],
  ) {
    this.assertNotSelf(actor.id, userId);
    const unique = this.restrictModeratorGrant(actor, permissionList);
    const user = await this.requireUser(userId);
    if (isPlatformAdmin(user.globalRole)) {
      throw new BadRequestException(
        'Retire d’abord le rôle admin avant de passer modérateur',
      );
    }

    user.globalRole = GlobalRole.MODERATOR;
    await this.users.save(user);
    await this.replacePermissions(userId, unique, actor.id);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'grant_moderator', userId, {
      permissions: unique,
    });
    return this.getUser(userId);
  }

  async updateModeratorPermissions(
    actor: AuthUser,
    userId: string,
    permissionList: AdminPermissionType[],
  ) {
    if (!isPlatformAdmin(actor.role ?? actor.globalRole)) {
      throw new ForbiddenException(
        'Seul un admin peut modifier les permissions d’un modo',
      );
    }
    const user = await this.requireUser(userId);
    if (toPlatformRole(user.globalRole) !== 'moderator') {
      throw new BadRequestException("Ce compte n'est pas modérateur");
    }
    const unique = this.normalizeModeratorPermissions(permissionList);
    await this.replacePermissions(userId, unique, actor.id);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'update_moderator_permissions', userId, {
      permissions: unique,
    });
    return this.getUser(userId);
  }

  async updatePermissions(
    actor: AuthUser,
    userId: string,
    permissionList: AdminPermissionType[],
  ) {
    const unique = this.normalizePermissions(permissionList);
    await this.requireUser(userId);
    await this.protectLastManageAdmins(userId, unique, actor.id);
    await this.replacePermissions(userId, unique, actor.id);

    const user = await this.requireUser(userId);
    if (toPlatformRole(user.globalRole) !== 'moderator') {
      user.globalRole =
        unique.length > 0 ? GlobalRole.ADMIN : GlobalRole.USER;
      await this.users.save(user);
    }
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'update_admin_permissions', userId, {
      permissions: unique,
    });
    return this.getUser(userId);
  }

  async revoke(actor: AuthUser, userId: string) {
    this.assertNotSelf(actor.id, userId);
    await this.requireUser(userId);
    await this.protectLastManageAdmins(userId, [], actor.id);

    const user = await this.requireUser(userId);
    user.globalRole = GlobalRole.USER;
    await this.users.save(user);
    await this.permissions.delete({ userId });
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'revoke_admin', userId, {});
    return { success: true };
  }

  async revokeModerator(actor: AuthUser, userId: string) {
    this.assertNotSelf(actor.id, userId);
    const user = await this.requireUser(userId);
    if (toPlatformRole(user.globalRole) !== 'moderator') {
      throw new BadRequestException("Ce compte n'est pas modérateur");
    }
    user.globalRole = GlobalRole.USER;
    await this.users.save(user);
    await this.permissions.delete({ userId });
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'revoke_moderator', userId, {});
    return { success: true };
  }

  async banUser(actor: AuthUser, userId: string, dto: BanUserDto) {
    this.assertNotSelf(actor.id, userId);
    const user = await this.requireUser(userId);
    if (isPlatformAdmin(user.globalRole)) {
      await this.protectLastManageAdmins(userId, [], actor.id);
    }
    user.status = UserStatus.BANNED;
    user.suspendedUntil = null;
    await this.users.save(user);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'ban_user', userId, { reason: dto.reason ?? null });
    return this.getUser(userId);
  }

  async unbanUser(actor: AuthUser, userId: string) {
    const user = await this.requireUser(userId);
    user.status = UserStatus.ACTIVE;
    user.suspendedUntil = null;
    await this.users.save(user);
    await this.audit(actor.id, 'unban_user', userId, {});
    return this.getUser(userId);
  }

  async timeoutUser(actor: AuthUser, userId: string, dto: TimeoutUserDto) {
    this.assertNotSelf(actor.id, userId);
    const user = await this.requireUser(userId);
    if (isPlatformAdmin(user.globalRole)) {
      throw new ForbiddenException('Impossible de mettre un admin en time-out');
    }
    if (
      toPlatformRole(user.globalRole) === 'moderator' &&
      toPlatformRole(actor.globalRole) !== 'admin'
    ) {
      throw new ForbiddenException('Seul un admin peut time-out un modo');
    }
    const until = new Date(Date.now() + dto.minutes * 60 * 1000);
    user.status = UserStatus.SUSPENDED;
    user.suspendedUntil = until;
    await this.users.save(user);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'timeout_user', userId, {
      minutes: dto.minutes,
      until: until.toISOString(),
      reason: dto.reason ?? null,
    });
    return this.getUser(userId);
  }

  async forceVerifyEmail(actor: AuthUser, userId: string) {
    const user = await this.requireUser(userId);
    user.emailVerifiedAt = new Date();
    await this.users.save(user);
    await this.audit(actor.id, 'force_verify_email', userId, {});
    return this.getUser(userId);
  }

  async forcePasswordReset(actor: AuthUser, userId: string) {
    const user = await this.requireUser(userId);
    await this.auth.forgotPassword(user.email);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'force_password_reset', userId, {});
    return { success: true };
  }

  async revokeUserSessions(actor: AuthUser, userId: string) {
    await this.requireUser(userId);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'revoke_sessions', userId, {});
    return { success: true };
  }

  async updateUser(actor: AuthUser, userId: string, dto: PatchAdminUserDto) {
    const user = await this.requireUser(userId);
    const profile = await this.profiles.findOne({ where: { userId } });
    if (!profile) {
      throw new NotFoundException('Profil introuvable');
    }

    const hasChange =
      Boolean(dto.email) ||
      Boolean(dto.pseudo) ||
      Boolean(dto.password) ||
      dto.firstName !== undefined ||
      dto.city !== undefined ||
      dto.bio !== undefined ||
      dto.positions !== undefined ||
      dto.strongFoot !== undefined ||
      dto.heightCm !== undefined ||
      dto.weightKg !== undefined ||
      dto.experienceLevel !== undefined ||
      dto.playingSinceYear !== undefined ||
      dto.availability !== undefined ||
      dto.clearAvatar === true;
    if (!hasChange) {
      throw new BadRequestException('Rien à modifier');
    }

    const changes: Record<string, unknown> = {};
    let revokeSessions = false;

    if (dto.email) {
      const email = dto.email.trim().toLowerCase();
      if (email !== user.email) {
        const taken = await this.users.findOne({ where: { email } });
        if (taken && taken.id !== userId) {
          throw new ConflictException('E-mail déjà enregistré');
        }
        user.email = email;
        user.emailVerifiedAt = new Date();
        changes.email = email;
        revokeSessions = true;
      }
    }

    if (dto.password) {
      user.passwordHash = await argon2.hash(dto.password);
      changes.password = true;
      revokeSessions = true;
    }

    if (dto.pseudo && dto.pseudo !== profile.pseudo) {
      const taken = await this.profiles.findOne({
        where: { pseudo: dto.pseudo, userId: Not(userId) },
      });
      if (taken) {
        throw new ConflictException('Pseudo déjà utilisé');
      }
      profile.pseudo = dto.pseudo.trim();
      changes.pseudo = profile.pseudo;
    }

    if (dto.firstName !== undefined) {
      profile.firstName = dto.firstName?.trim() || null;
      changes.firstName = profile.firstName;
    }
    if (dto.city !== undefined) {
      profile.city = dto.city?.trim() || null;
      changes.city = profile.city;
    }
    if (dto.bio !== undefined) {
      profile.bio = dto.bio?.trim() || null;
      changes.bio = profile.bio;
    }
    if (dto.positions !== undefined) {
      const unique = [...new Set(dto.positions)];
      profile.positions = unique;
      profile.position = unique[0] ? fifaToLegacyPosition(unique[0]) : null;
      changes.positions = unique;
    }
    if (dto.strongFoot !== undefined) {
      profile.strongFoot = dto.strongFoot;
      changes.strongFoot = dto.strongFoot;
    }
    if (dto.heightCm !== undefined) {
      profile.heightCm = dto.heightCm;
      changes.heightCm = dto.heightCm;
    }
    if (dto.weightKg !== undefined) {
      profile.weightKg = dto.weightKg;
      changes.weightKg = dto.weightKg;
    }
    if (dto.experienceLevel !== undefined) {
      profile.experienceLevel = dto.experienceLevel;
      changes.experienceLevel = dto.experienceLevel;
    }
    if (dto.playingSinceYear !== undefined) {
      profile.playingSinceYear = dto.playingSinceYear;
      changes.playingSinceYear = dto.playingSinceYear;
    }
    if (dto.availability !== undefined) {
      profile.availability = [...new Set(dto.availability)];
      changes.availability = profile.availability;
    }
    if (dto.clearAvatar) {
      const avatar = await this.avatars.findOne({ where: { userId } });
      if (avatar) await this.avatars.remove(avatar);
      profile.avatarUrl = null;
      changes.avatar = null;
    }

    await this.users.save(user);
    await this.profiles.save(profile);
    if (revokeSessions) {
      await this.auth.invalidateSessions(userId);
    }
    await this.audit(actor.id, 'update_user', userId, changes);
    return this.getUser(userId);
  }

  async deleteUser(actor: AuthUser, userId: string) {
    this.assertNotSelf(actor.id, userId);
    const user = await this.requireUser(userId);
    if (isPlatformAdmin(user.globalRole)) {
      await this.protectLastManageAdmins(userId, [], actor.id);
    }

    const profile = await this.profiles.findOne({ where: { userId } });
    if (profile) {
      profile.pseudo = `deleted_${user.id.replace(/-/g, '').slice(0, 12)}`;
      await this.profiles.save(profile);
    }

    user.status = UserStatus.DELETED;
    user.email = `deleted+${user.id}@futbolia.invalid`;
    await this.users.save(user);
    await this.permissions.delete({ userId });
    await this.auth.invalidateSessions(userId);
    await this.users.softDelete(user.id);
    await this.audit(actor.id, 'delete_user', userId, {});
    return { success: true };
  }

  async listTournaments() {
    const rows = await this.tournaments.find({
      relations: { createdBy: { profile: true } },
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return Promise.all(
      rows.map(async (t) => {
        const [memberCount, teamCount, matchCount] = await Promise.all([
          this.members.count({ where: { tournamentId: t.id } }),
          this.teams.count({ where: { tournamentId: t.id } }),
          this.matches.count({ where: { tournamentId: t.id } }),
        ]);
        return {
          id: t.id,
          name: t.name,
          status: t.status,
          mode: t.mode,
          visibility: t.visibility,
          startsAt: t.startsAt,
          location: t.location,
          createdAt: t.createdAt,
          owner: {
            id: t.createdById,
            pseudo: t.createdBy?.profile?.pseudo ?? '',
            role: toPlatformRole(t.createdBy?.globalRole),
          },
          memberCount,
          teamCount,
          matchCount,
        };
      }),
    );
  }

  async patchTournament(
    actor: AuthUser,
    tournamentId: string,
    dto: PatchTournamentDto,
  ) {
    const tournament = await this.requireTournament(tournamentId);
    if (dto.name) tournament.name = dto.name.trim();
    if (dto.description !== undefined) {
      tournament.description = dto.description?.trim() || null;
    }
    if (dto.startsAt) tournament.startsAt = new Date(dto.startsAt);
    if (dto.location) tournament.location = dto.location.trim();
    if (dto.maxTeams !== undefined) tournament.maxTeams = dto.maxTeams;
    if (dto.startersCount !== undefined) {
      tournament.startersCount = dto.startersCount;
    }
    tournament.substitutesCount = tournament.startersCount;
    if (dto.rulesText !== undefined) {
      tournament.rulesText = dto.rulesText?.trim() || null;
    }
    if (dto.mode) tournament.mode = dto.mode;
    if (dto.visibility) tournament.visibility = dto.visibility;
    if (dto.status) tournament.status = dto.status;
    await this.tournaments.save(tournament);
    await this.audit(actor.id, 'patch_tournament', tournamentId, {
      ...dto,
    });
    return { success: true, id: tournament.id };
  }

  async deleteTournament(actor: AuthUser, tournamentId: string) {
    await this.requireTournament(tournamentId);
    await this.tournaments.delete({ id: tournamentId });
    await this.audit(actor.id, 'delete_tournament', tournamentId, {});
    return { success: true };
  }

  async transferOwner(
    actor: AuthUser,
    tournamentId: string,
    newOwnerId: string,
  ) {
    const tournament = await this.requireTournament(tournamentId);
    await this.requireUser(newOwnerId);
    const previous = tournament.createdById;
    tournament.createdById = newOwnerId;
    await this.tournaments.save(tournament);

    let membership = await this.members.findOne({
      where: { tournamentId, userId: newOwnerId },
    });
    if (!membership) {
      membership = this.members.create({
        tournamentId,
        userId: newOwnerId,
        role: TournamentMemberRole.ORGANIZER,
      });
    } else {
      membership.role = TournamentMemberRole.ORGANIZER;
    }
    await this.members.save(membership);

    await this.audit(actor.id, 'transfer_owner', tournamentId, {
      from: previous,
      to: newOwnerId,
    });
    return { success: true };
  }

  async forceTeamStatus(
    actor: AuthUser,
    teamId: string,
    dto: ForceTeamStatusDto,
  ) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    team.status = dto.status;
    await this.teams.save(team);
    await this.audit(actor.id, 'force_team_status', teamId, {
      status: dto.status,
    });
    return { id: team.id, status: team.status };
  }

  async patchTeam(actor: AuthUser, teamId: string, dto: PatchAdminTeamDto) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    if (dto.name) team.name = dto.name.trim();
    if (dto.status) team.status = dto.status;
    await this.teams.save(team);
    await this.audit(actor.id, 'patch_team', teamId, { ...dto });
    return { id: team.id, name: team.name, status: team.status };
  }

  async deleteTeam(actor: AuthUser, teamId: string) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    await this.teams.remove(team);
    await this.audit(actor.id, 'delete_team', teamId, {});
    return { success: true };
  }

  async patchMatch(actor: AuthUser, matchId: string, dto: PatchAdminMatchDto) {
    const match = await this.matches.findOne({ where: { id: matchId } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    if (dto.scheduledAt !== undefined) {
      match.scheduledAt = dto.scheduledAt ? new Date(dto.scheduledAt) : null;
    }
    if (dto.homeScore !== undefined) match.homeScore = dto.homeScore;
    if (dto.awayScore !== undefined) match.awayScore = dto.awayScore;
    if (dto.status) {
      match.status = dto.status;
      if (dto.status === MatchStatus.CANCELLED) {
        match.homeScore = null;
        match.awayScore = null;
      }
    } else if (match.homeScore != null && match.awayScore != null) {
      match.status = MatchStatus.FINISHED;
    }
    await this.matches.save(match);
    await this.audit(actor.id, 'patch_match', matchId, { ...dto });
    return {
      id: match.id,
      status: match.status,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      scheduledAt: match.scheduledAt,
    };
  }

  async deleteMatch(actor: AuthUser, matchId: string) {
    const match = await this.matches.findOne({ where: { id: matchId } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    await this.matches.remove(match);
    await this.audit(actor.id, 'delete_match', matchId, {});
    return { success: true };
  }

  async listPickupMatches() {
    const rows = await this.pickups.find({
      relations: { createdBy: { profile: true } },
      order: { scheduledAt: 'DESC' },
      take: 100,
    });
    return rows.map((m) => ({
      id: m.id,
      location: m.location,
      scheduledAt: m.scheduledAt,
      status: m.status,
      playersPerTeam: m.playersPerTeam,
      visibility: m.visibility,
      homeScore: m.homeScore,
      awayScore: m.awayScore,
      host: {
        id: m.createdById,
        pseudo: m.createdBy?.profile?.pseudo ?? '',
      },
    }));
  }

  async patchPickup(actor: AuthUser, id: string, dto: PatchAdminPickupDto) {
    const match = await this.pickups.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match libre introuvable');
    }
    if (dto.location) match.location = dto.location.trim();
    if (dto.scheduledAt) match.scheduledAt = new Date(dto.scheduledAt);
    if (dto.playersPerTeam !== undefined) {
      match.playersPerTeam = dto.playersPerTeam;
    }
    if (dto.homeScore !== undefined) match.homeScore = dto.homeScore;
    if (dto.awayScore !== undefined) match.awayScore = dto.awayScore;
    if (dto.status) {
      match.status = dto.status;
      if (dto.status === PickupMatchStatus.CANCELLED) {
        match.homeScore = null;
        match.awayScore = null;
      }
    } else if (match.homeScore != null && match.awayScore != null) {
      match.status = PickupMatchStatus.FINISHED;
    }
    await this.pickups.save(match);
    await this.audit(actor.id, 'patch_pickup', id, { ...dto });
    return { success: true, id: match.id, status: match.status };
  }

  async deletePickup(actor: AuthUser, id: string) {
    const match = await this.pickups.findOne({ where: { id } });
    if (!match) {
      throw new NotFoundException('Match libre introuvable');
    }
    await this.pickups.remove(match);
    await this.audit(actor.id, 'delete_pickup', id, {});
    return { success: true };
  }

  async listTournamentTeams(tournamentId: string) {
    await this.requireTournament(tournamentId);
    const rows = await this.teams.find({
      where: { tournamentId },
      order: { createdAt: 'ASC' },
    });
    return rows.map((t) => ({
      id: t.id,
      name: t.name,
      status: t.status,
      captainId: t.captainId,
    }));
  }

  async cancelMatch(actor: AuthUser, matchId: string) {
    const match = await this.matches.findOne({ where: { id: matchId } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    match.status = MatchStatus.CANCELLED;
    await this.matches.save(match);
    await this.audit(actor.id, 'cancel_match', matchId, {});
    return { id: match.id, status: match.status };
  }

  async listTournamentMatches(tournamentId: string) {
    await this.requireTournament(tournamentId);
    const rows = await this.matches.find({
      where: { tournamentId },
      order: { scheduledAt: 'ASC' },
    });
    return rows.map((m) => ({
      id: m.id,
      status: m.status,
      scheduledAt: m.scheduledAt,
      homeTeamId: m.homeTeamId,
      awayTeamId: m.awayTeamId,
      homeScore: m.homeScore,
      awayScore: m.awayScore,
    }));
  }

  listReportReasons() {
    const toOptions = (type: ReportType) =>
      reportReasonsFor(type).map((code) => ({
        code,
        label: reportReasonLabel(code, type),
      }));
    return {
      message: toOptions(ReportType.MESSAGE),
      direct_message: toOptions(ReportType.DIRECT_MESSAGE),
      user: toOptions(ReportType.USER),
      tournament: toOptions(ReportType.TOURNAMENT),
    };
  }

  async createReport(reporterId: string, dto: CreateReportDto) {
    const comment = dto.comment?.trim() || null;
    if (dto.reasonCode === ReportReasonCode.OTHER && !comment) {
      throw new BadRequestException(
        'Ajoute un commentaire pour le motif « Autre »',
      );
    }
    if (
      dto.reasonCode === ReportReasonCode.FAKE_PROFILE &&
      dto.type !== ReportType.USER
    ) {
      throw new BadRequestException(
        'Ce motif s’applique uniquement à un profil',
      );
    }

    const allowed = reportReasonsFor(dto.type);
    if (!allowed.includes(dto.reasonCode)) {
      throw new BadRequestException('Motif de signalement invalide');
    }

    await this.assertReportTarget(reporterId, dto.type, dto.targetId);

    const duplicate = await this.reports.findOne({
      where: {
        reporterId,
        type: dto.type,
        targetId: dto.targetId,
        status: ReportStatus.OPEN,
      },
    });
    if (duplicate) {
      throw new ConflictException('Tu as déjà signalé cet élément');
    }

    const label = reportReasonLabel(dto.reasonCode, dto.type);
    const reason = comment ? `${label} — ${comment}` : label;

    const saved = await this.reports.save(
      this.reports.create({
        type: dto.type,
        targetId: dto.targetId,
        reporterId,
        reason,
        reasonCode: dto.reasonCode,
        comment,
        status: ReportStatus.OPEN,
      }),
    );
    return { id: saved.id, status: saved.status };
  }

  async listReports() {
    const rows = await this.reports.find({
      relations: { reporter: { profile: true } },
      order: { createdAt: 'DESC' },
      take: 100,
    });

    const messageIds = rows
      .filter((r) => r.type === ReportType.MESSAGE)
      .map((r) => r.targetId);
    const dmIds = rows
      .filter((r) => r.type === ReportType.DIRECT_MESSAGE)
      .map((r) => r.targetId);
    const userIds = rows
      .filter((r) => r.type === ReportType.USER)
      .map((r) => r.targetId);

    const [messages, dms, users] = await Promise.all([
      messageIds.length
        ? this.messages.find({
            where: { id: In(messageIds) },
            relations: { author: { profile: true } },
          })
        : [],
      dmIds.length
        ? this.directMessages.find({
            where: { id: In(dmIds) },
            relations: { sender: { profile: true } },
          })
        : [],
      userIds.length
        ? this.users.find({
            where: { id: In(userIds) },
            relations: { profile: true },
          })
        : [],
    ]);

    const messageMap = new Map(messages.map((m) => [m.id, m]));
    const dmMap = new Map(dms.map((m) => [m.id, m]));
    const userMap = new Map(users.map((u) => [u.id, u]));

    return rows.map((r) => {
      let target: {
        userId?: string;
        pseudo?: string;
        body?: string;
        status?: string;
        suspendedUntil?: Date | null;
      } = {};
      if (r.type === ReportType.MESSAGE) {
        const m = messageMap.get(r.targetId);
        target = {
          userId: m?.authorId,
          pseudo: m?.author?.profile?.pseudo ?? '',
          body: m?.body,
          status: m?.author?.status,
          suspendedUntil: m?.author?.suspendedUntil ?? null,
        };
      } else if (r.type === ReportType.DIRECT_MESSAGE) {
        const m = dmMap.get(r.targetId);
        target = {
          userId: m?.senderId,
          pseudo: m?.sender?.profile?.pseudo ?? '',
          body: m?.content,
          status: m?.sender?.status,
          suspendedUntil: m?.sender?.suspendedUntil ?? null,
        };
      } else if (r.type === ReportType.USER) {
        const u = userMap.get(r.targetId);
        target = {
          userId: u?.id,
          pseudo: u?.profile?.pseudo ?? '',
          status: u?.status,
          suspendedUntil: u?.suspendedUntil ?? null,
        };
      }

      return {
        id: r.id,
        type: r.type,
        typeLabel: reportTypeLabel(r.type),
        targetId: r.targetId,
        reason: r.reason,
        reasonCode: r.reasonCode,
        comment: r.comment,
        status: r.status,
        createdAt: r.createdAt,
        reviewedAt: r.reviewedAt,
        reporter: {
          id: r.reporterId,
          pseudo: r.reporter?.profile?.pseudo ?? '',
          role: toPlatformRole(r.reporter?.globalRole),
        },
        target,
      };
    });
  }

  private async assertReportTarget(
    reporterId: string,
    type: ReportType,
    targetId: string,
  ) {
    if (type === ReportType.USER) {
      if (targetId === reporterId) {
        throw new BadRequestException(
          'Tu ne peux pas signaler ton propre profil',
        );
      }
      const user = await this.users.findOne({ where: { id: targetId } });
      if (!user || user.deletedAt) {
        throw new NotFoundException('Profil introuvable');
      }
      return;
    }

    if (type === ReportType.MESSAGE) {
      const message = await this.messages.findOne({
        where: { id: targetId },
      });
      if (!message) {
        throw new NotFoundException('Message introuvable');
      }
      if (message.authorId === reporterId) {
        throw new BadRequestException(
          'Tu ne peux pas signaler ton propre message',
        );
      }
      return;
    }

    if (type === ReportType.DIRECT_MESSAGE) {
      const message = await this.directMessages.findOne({
        where: { id: targetId },
        relations: { conversation: true },
      });
      if (!message) {
        throw new NotFoundException('Message introuvable');
      }
      if (message.senderId === reporterId) {
        throw new BadRequestException(
          'Tu ne peux pas signaler ton propre message',
        );
      }
      const conv = message.conversation;
      if (conv.user1Id !== reporterId && conv.user2Id !== reporterId) {
        throw new ForbiddenException('Tu n’as pas accès à cette conversation');
      }
      return;
    }

    if (type === ReportType.TOURNAMENT) {
      const tournament = await this.tournaments.findOne({
        where: { id: targetId },
      });
      if (!tournament) {
        throw new NotFoundException('Tournoi introuvable');
      }
    }
  }

  async resolveReport(actor: AuthUser, reportId: string, dto: ResolveReportDto) {
    const report = await this.reports.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('Signalement introuvable');
    }

    const closed =
      report.status === ReportStatus.CLOSED ||
      report.status === ReportStatus.DISMISSED;

    if (dto.status === ReportStatus.OPEN) {
      if (report.status === ReportStatus.OPEN) {
        throw new BadRequestException('Ce signalement est déjà à traiter');
      }
      report.status = ReportStatus.OPEN;
      report.reviewedById = null;
      report.reviewedAt = null;
      await this.reports.save(report);
      await this.audit(actor.id, 'reopen_report', reportId, {});
      return { success: true, status: report.status };
    }

    if (dto.status === ReportStatus.REVIEWED) {
      if (report.status === ReportStatus.REVIEWED) {
        throw new BadRequestException('Ce signalement est déjà traité');
      }
      if (report.status === ReportStatus.OPEN) {
        await this.applyReportActions(actor, report, dto);
      }
      report.status = ReportStatus.REVIEWED;
      report.reviewedById = actor.id;
      report.reviewedAt = new Date();
      await this.reports.save(report);
      await this.audit(actor.id, closed ? 'unclose_report' : 'review_report', reportId, {
        action: dto.action ?? 'none',
        timeoutMinutes: dto.timeoutMinutes ?? null,
        deleteMessage: Boolean(dto.deleteMessage),
      });
      return { success: true, status: report.status };
    }

    if (
      dto.status !== ReportStatus.CLOSED &&
      dto.status !== ReportStatus.DISMISSED
    ) {
      throw new BadRequestException('Statut de revue invalide');
    }
    if (closed) {
      throw new BadRequestException('Ce signalement est déjà clôturé');
    }

    report.status = dto.status;
    report.reviewedById = actor.id;
    report.reviewedAt = new Date();
    await this.reports.save(report);
    await this.audit(actor.id, 'close_report', reportId, {
      status: dto.status,
    });
    return { success: true, status: report.status };
  }

  private async applyReportActions(
    actor: AuthUser,
    report: Report,
    dto: ResolveReportDto,
  ) {
    const targetUserId = await this.reportedUserId(report);
    if (dto.action === 'timeout') {
      if (!dto.timeoutMinutes) {
        throw new BadRequestException('Indique la durée du time-out');
      }
      if (!targetUserId) {
        throw new BadRequestException('Impossible d’identifier le joueur');
      }
      await this.timeoutUser(actor, targetUserId, {
        minutes: dto.timeoutMinutes,
        reason: report.reason,
      });
    } else if (dto.action === 'ban') {
      if (!targetUserId) {
        throw new BadRequestException('Impossible d’identifier le joueur');
      }
      await this.banUser(actor, targetUserId, { reason: report.reason });
    }
    if (dto.deleteMessage) {
      await this.deleteReportedMessage(actor, report);
    }
  }

  async deleteReport(actor: AuthUser, reportId: string) {
    const report = await this.reports.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('Signalement introuvable');
    }
    await this.reports.remove(report);
    await this.audit(actor.id, 'delete_report', reportId, {
      type: report.type,
      targetId: report.targetId,
    });
    return { success: true };
  }

  private async reportedUserId(report: Report): Promise<string | null> {
    if (report.type === ReportType.USER) return report.targetId;
    if (report.type === ReportType.MESSAGE) {
      const message = await this.messages.findOne({
        where: { id: report.targetId },
      });
      return message?.authorId ?? null;
    }
    if (report.type === ReportType.DIRECT_MESSAGE) {
      const message = await this.directMessages.findOne({
        where: { id: report.targetId },
      });
      return message?.senderId ?? null;
    }
    return null;
  }

  private async deleteReportedMessage(actor: AuthUser, report: Report) {
    if (report.type === ReportType.MESSAGE) {
      try {
        await this.deleteChatMessage(actor, report.targetId);
      } catch {
        // Message déjà supprimé
      }
      return;
    }
    if (report.type === ReportType.DIRECT_MESSAGE) {
      const message = await this.directMessages.findOne({
        where: { id: report.targetId },
      });
      if (!message || message.deletedAt) return;
      message.deletedAt = new Date();
      await this.directMessages.save(message);
      await this.audit(actor.id, 'delete_direct_message', message.id, {});
    }
  }

  async listDeletedMessages() {
    const rows = await this.messages.find({
      where: { deletedAt: Not(IsNull()) },
      relations: { author: { profile: true } },
      order: { deletedAt: 'DESC' },
      take: 80,
    });
    return rows.map((m) => ({
      id: m.id,
      tournamentId: m.tournamentId,
      body: m.body,
      createdAt: m.createdAt,
      deletedAt: m.deletedAt,
      author: {
        id: m.authorId,
        pseudo: m.author?.profile?.pseudo ?? '',
        role: toPlatformRole(m.author?.globalRole),
      },
    }));
  }

  async deleteChatMessage(actor: AuthUser, messageId: string) {
    const message = await this.messages.findOne({ where: { id: messageId } });
    if (!message || message.deletedAt) {
      throw new NotFoundException('Message introuvable');
    }
    message.deletedAt = new Date();
    message.deletedById = actor.id;
    await this.messages.save(message);
    await this.audit(actor.id, 'delete_chat_message', messageId, {
      tournamentId: message.tournamentId,
    });
    return { success: true };
  }

  async statsOverview() {
    const [
      users,
      admins,
      moderators,
      tournaments,
      matches,
      openReports,
    ] = await Promise.all([
      this.users.count(),
      this.users.count({
        where: [
          { globalRole: GlobalRole.ADMIN },
          { globalRole: GlobalRole.SUPER_ADMIN },
        ],
      }),
      this.users.count({
        where: { globalRole: GlobalRole.MODERATOR },
      }),
      this.tournaments.count(),
      this.matches.count(),
      this.reports.count({ where: { status: ReportStatus.OPEN } }),
    ]);
    return {
      users,
      admins,
      moderators,
      tournaments,
      matches,
      openReports,
    };
  }

  async securityOverview() {
    let databaseConnected = false;
    try {
      await this.db.query('SELECT 1');
      databaseConnected = true;
    } catch {
      databaseConnected = false;
    }
    const [activeSessions, recentLogs] = await Promise.all([
      this.refreshTokens.count({ where: { revokedAt: IsNull() } }),
      this.auditLogs.find({
        relations: { admin: { profile: true } },
        order: { createdAt: 'DESC' },
        take: 40,
      }),
    ]);
    return {
      databaseConnected,
      activeSessions,
      logs: recentLogs.map((log) => ({
        id: log.id,
        action: log.action,
        targetId: log.targetId,
        createdAt: log.createdAt,
        admin: {
          id: log.adminId,
          pseudo: log.admin?.profile?.pseudo ?? '',
          role: toPlatformRole(log.admin?.globalRole),
        },
      })),
    };
  }

  private async listStaff(roles: string[]) {
    const users = await this.users.find({
      where: roles.map((globalRole) => ({ globalRole: globalRole as GlobalRole })),
      relations: { profile: true },
    });
    const permMap = await this.permissionMap(users.map((u) => u.id));
    return users.map((user) =>
      this.toListUser(user, permMap.get(user.id) ?? []),
    );
  }

  private async permissionMap(userIds: string[]) {
    const map = new Map<string, string[]>();
    if (userIds.length === 0) {
      return map;
    }
    const rows = await this.permissions.find({
      where: { userId: In(userIds) },
    });
    for (const row of rows) {
      const list = map.get(row.userId) ?? [];
      list.push(row.permission);
      map.set(row.userId, list);
    }
    return map;
  }

  private toListUser(user: User, permissions: string[]) {
    return {
      id: user.id,
      email: user.email,
      pseudo: user.profile?.pseudo ?? '',
      status: user.status,
      suspendedUntil: user.suspendedUntil,
      role: toPlatformRole(user.globalRole),
      permissions,
    };
  }

  private normalizePermissions(list: AdminPermissionType[]) {
    if (!list.length) {
      throw new BadRequestException('Choisis au moins une permission');
    }
    const allowed = new Set(ALL_ADMIN_PERMISSIONS);
    const unique = [...new Set(list)];
    for (const item of unique) {
      if (!allowed.has(item)) {
        throw new BadRequestException(`Permission inconnue : ${item}`);
      }
    }
    return unique;
  }

  private normalizeModeratorPermissions(list?: AdminPermissionType[]) {
    const unique = this.normalizePermissions(
      list?.length ? list : [AdminPermissionType.MODERATE_CONTENT],
    );
    if (unique.includes(AdminPermissionType.MANAGE_ADMINS)) {
      throw new BadRequestException(
        'Un modérateur ne peut pas gérer les admins. Passe-le admin pour ça.',
      );
    }
    if (!unique.includes(AdminPermissionType.MODERATE_CONTENT)) {
      unique.push(AdminPermissionType.MODERATE_CONTENT);
    }
    return unique;
  }

  private restrictModeratorGrant(
    actor: AuthUser,
    list?: AdminPermissionType[],
  ) {
    if (isPlatformAdmin(actor.role ?? actor.globalRole)) {
      return this.normalizeModeratorPermissions(list);
    }
    return this.normalizeModeratorPermissions([
      AdminPermissionType.MODERATE_CONTENT,
    ]);
  }

  private async replacePermissions(
    userId: string,
    permissionList: AdminPermissionType[],
    grantedById: string,
  ) {
    await this.permissions.delete({ userId });
    if (permissionList.length === 0) {
      return;
    }
    await this.permissions.save(
      permissionList.map((permission) =>
        this.permissions.create({
          userId,
          permission,
          grantedById,
        }),
      ),
    );
  }

  private async protectLastManageAdmins(
    targetUserId: string,
    nextPermissions: AdminPermissionType[],
    actorId: string,
  ) {
    const stillHas = nextPermissions.includes(
      AdminPermissionType.MANAGE_ADMINS,
    );
    if (stillHas) {
      return;
    }

    const holders = await this.permissions.find({
      where: { permission: AdminPermissionType.MANAGE_ADMINS },
    });
    const others = holders.filter((row) => row.userId !== targetUserId);
    if (others.length === 0) {
      throw new ForbiddenException(
        'Impossible de retirer le dernier admin principal (manage_admins)',
      );
    }

    if (targetUserId === actorId) {
      throw new ForbiddenException(
        'Tu ne peux pas retirer ta propre permission manage_admins',
      );
    }
  }

  private assertNotSelf(actorId: string, userId: string) {
    if (actorId === userId) {
      throw new ForbiddenException(
        'Tu ne peux pas modifier ton propre accès ici',
      );
    }
  }

  private async requireUser(id: string) {
    const user = await this.users.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    return user;
  }

  private async requireTournament(id: string) {
    const tournament = await this.tournaments.findOne({ where: { id } });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    return tournament;
  }

  private async audit(
    adminId: string,
    action: string,
    targetId: string | null,
    metadata: Record<string, unknown>,
  ) {
    await this.auditLogs.save(
      this.auditLogs.create({
        adminId,
        action,
        targetId,
        metadata,
      }),
    );
  }
}
