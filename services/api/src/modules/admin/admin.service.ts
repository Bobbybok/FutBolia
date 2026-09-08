import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, In, IsNull, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  AdminPermissionType,
  ALL_ADMIN_PERMISSIONS,
  GlobalRole,
  isPlatformAdmin,
  MatchStatus,
  ReportStatus,
  TeamStatus,
  toPlatformRole,
  TournamentMemberRole,
  TournamentStatus,
  UserStatus,
} from '../../common/enums';
import { User } from '../users/entities/user.entity';
import { AdminPermission } from './entities/admin-permission.entity';
import { AuditLog } from './entities/audit-log.entity';
import { Report } from './entities/report.entity';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { Team } from '../teams/entities/team.entity';
import { Match } from '../matches/entities/match.entity';
import { TournamentChatMessage } from '../chat/entities/tournament-chat-message.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
import { AuthService } from '../auth/auth.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import {
  BanUserDto,
  CreateReportDto,
  ForceTeamStatusDto,
  PatchTournamentDto,
  ResolveReportDto,
} from './dto/admin.dto';

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

  private get messages(): Repository<TournamentChatMessage> {
    return this.db.getRepository(TournamentChatMessage);
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
    const qb = this.users
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.profile', 'profile')
      .where('user.deleted_at IS NULL')
      .orderBy('user.created_at', 'DESC')
      .take(40);

    if (q) {
      qb.andWhere('(user.email ILIKE :q OR profile.pseudo ILIKE :q)', {
        q: `%${q}%`,
      });
    }

    const users = await qb.getMany();
    const permMap = await this.permissionMap(users.map((u) => u.id));
    return users.map((user) => this.toListUser(user, permMap.get(user.id) ?? []));
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
      profile: {
        pseudo: user.profile.pseudo,
        firstName: user.profile.firstName,
        city: user.profile.city,
      },
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
    await this.users.save(user);
    await this.auth.invalidateSessions(userId);
    await this.audit(actor.id, 'ban_user', userId, { reason: dto.reason ?? null });
    return this.getUser(userId);
  }

  async unbanUser(actor: AuthUser, userId: string) {
    const user = await this.requireUser(userId);
    user.status = UserStatus.ACTIVE;
    await this.users.save(user);
    await this.audit(actor.id, 'unban_user', userId, {});
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
    if (dto.status) tournament.status = dto.status;
    await this.tournaments.save(tournament);
    await this.audit(actor.id, 'patch_tournament', tournamentId, {
      name: dto.name ?? null,
      status: dto.status ?? null,
    });
    return { success: true };
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

  async createReport(reporterId: string, dto: CreateReportDto) {
    const saved = await this.reports.save(
      this.reports.create({
        type: dto.type,
        targetId: dto.targetId,
        reporterId,
        reason: dto.reason.trim(),
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
    return rows.map((r) => ({
      id: r.id,
      type: r.type,
      targetId: r.targetId,
      reason: r.reason,
      status: r.status,
      createdAt: r.createdAt,
      reviewedAt: r.reviewedAt,
      reporter: {
        id: r.reporterId,
        pseudo: r.reporter?.profile?.pseudo ?? '',
        role: toPlatformRole(r.reporter?.globalRole),
      },
    }));
  }

  async resolveReport(actor: AuthUser, reportId: string, dto: ResolveReportDto) {
    if (
      dto.status !== ReportStatus.REVIEWED &&
      dto.status !== ReportStatus.DISMISSED
    ) {
      throw new BadRequestException('Statut de revue invalide');
    }
    const report = await this.reports.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('Signalement introuvable');
    }
    report.status = dto.status;
    report.reviewedById = actor.id;
    report.reviewedAt = new Date();
    await this.reports.save(report);
    await this.audit(actor.id, 'resolve_report', reportId, { status: dto.status });
    return { success: true };
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
