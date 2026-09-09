import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { AdminPermissionType } from '../../common/enums';
import { PermissionsGuard } from './guards/permissions.guard';
import { RequirePermission } from './guards/decorators/require-permission.decorator';
import { AdminService } from './admin.service';
import {
  AdminUserQueryDto,
  BanUserDto,
  ForceTeamStatusDto,
  GrantAdminDto,
  GrantModeratorDto,
  PatchAdminUserDto,
  PatchTournamentDto,
  ResolveReportDto,
  TimeoutUserDto,
  TransferOwnerDto,
  UpdateAdminPermissionsDto,
} from './dto/admin.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('admins')
  @RequirePermission(AdminPermissionType.MANAGE_ADMINS)
  listAdmins() {
    return this.admin.listAdmins();
  }

  @Post('admins/:userId/grant')
  @RequirePermission(AdminPermissionType.MANAGE_ADMINS)
  grant(
    @CurrentUser() actor: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: GrantAdminDto,
  ) {
    return this.admin.grant(actor, userId, dto.permissions);
  }

  @Patch('admins/:userId/permissions')
  @RequirePermission(AdminPermissionType.MANAGE_ADMINS)
  updatePermissions(
    @CurrentUser() actor: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: UpdateAdminPermissionsDto,
  ) {
    return this.admin.updatePermissions(actor, userId, dto.permissions);
  }

  @Delete('admins/:userId/revoke')
  @RequirePermission(AdminPermissionType.MANAGE_ADMINS)
  revoke(
    @CurrentUser() actor: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.admin.revoke(actor, userId);
  }

  @Get('moderators')
  @RequirePermission(
    AdminPermissionType.MANAGE_ADMINS,
    AdminPermissionType.MANAGE_MODERATORS,
  )
  listModerators() {
    return this.admin.listModerators();
  }

  @Post('moderators/:userId/grant')
  @RequirePermission(
    AdminPermissionType.MANAGE_ADMINS,
    AdminPermissionType.MANAGE_MODERATORS,
  )
  grantModerator(
    @CurrentUser() actor: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: GrantModeratorDto,
  ) {
    return this.admin.grantModerator(actor, userId, dto.permissions);
  }

  @Patch('moderators/:userId/permissions')
  @RequirePermission(AdminPermissionType.MANAGE_ADMINS)
  updateModeratorPermissions(
    @CurrentUser() actor: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: GrantModeratorDto,
  ) {
    return this.admin.updateModeratorPermissions(
      actor,
      userId,
      dto.permissions ?? [],
    );
  }

  @Delete('moderators/:userId/revoke')
  @RequirePermission(
    AdminPermissionType.MANAGE_ADMINS,
    AdminPermissionType.MANAGE_MODERATORS,
  )
  revokeModerator(
    @CurrentUser() actor: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.admin.revokeModerator(actor, userId);
  }

  @Get('users')
  @RequirePermission(
    AdminPermissionType.MANAGE_USERS,
    AdminPermissionType.MANAGE_ADMINS,
    AdminPermissionType.MANAGE_MODERATORS,
  )
  searchUsers(@Query() query: AdminUserQueryDto) {
    return this.admin.searchUsers(query.q);
  }

  @Get('users/:id')
  @RequirePermission(
    AdminPermissionType.MANAGE_USERS,
    AdminPermissionType.MANAGE_ADMINS,
  )
  getUser(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.getUser(id);
  }

  @Post('users/:id/ban')
  @RequirePermission(AdminPermissionType.MANAGE_USERS)
  banUser(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: BanUserDto,
  ) {
    return this.admin.banUser(actor, id, dto);
  }

  @Post('users/:id/unban')
  @RequirePermission(AdminPermissionType.MANAGE_USERS)
  unbanUser(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.unbanUser(actor, id);
  }

  @Post('users/:id/timeout')
  @RequirePermission(AdminPermissionType.MODERATE_CONTENT)
  timeoutUser(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: TimeoutUserDto,
  ) {
    return this.admin.timeoutUser(actor, id, dto);
  }

  @Post('users/:id/verify-email')
  @RequirePermission(AdminPermissionType.MANAGE_USERS)
  forceVerify(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.forceVerifyEmail(actor, id);
  }

  @Post('users/:id/reset-password')
  @RequirePermission(AdminPermissionType.MANAGE_USERS)
  forceReset(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.forcePasswordReset(actor, id);
  }

  @Post('users/:id/revoke-sessions')
  @RequirePermission(
    AdminPermissionType.MANAGE_USERS,
    AdminPermissionType.VIEW_SECURITY,
  )
  revokeSessions(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.revokeUserSessions(actor, id);
  }

  @Patch('users/:id')
  @RequirePermission(AdminPermissionType.MANAGE_USERS)
  patchUser(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PatchAdminUserDto,
  ) {
    return this.admin.updateUser(actor, id, dto);
  }

  @Delete('users/:id')
  @RequirePermission(AdminPermissionType.MANAGE_USERS)
  deleteUser(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.deleteUser(actor, id);
  }

  @Get('tournaments')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  listTournaments() {
    return this.admin.listTournaments();
  }

  @Patch('tournaments/:id')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  patchTournament(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PatchTournamentDto,
  ) {
    return this.admin.patchTournament(actor, id, dto);
  }

  @Delete('tournaments/:id')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  deleteTournament(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.deleteTournament(actor, id);
  }

  @Post('tournaments/:id/transfer')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  transferOwner(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: TransferOwnerDto,
  ) {
    return this.admin.transferOwner(actor, id, dto.userId);
  }

  @Get('tournaments/:id/teams')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  listTeams(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.listTournamentTeams(id);
  }

  @Get('tournaments/:id/matches')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  listMatches(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.listTournamentMatches(id);
  }

  @Post('teams/:id/status')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  forceTeamStatus(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ForceTeamStatusDto,
  ) {
    return this.admin.forceTeamStatus(actor, id, dto);
  }

  @Post('matches/:id/cancel')
  @RequirePermission(AdminPermissionType.MANAGE_TOURNAMENTS)
  cancelMatch(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.cancelMatch(actor, id);
  }

  @Get('reports')
  @RequirePermission(AdminPermissionType.MODERATE_CONTENT)
  listReports() {
    return this.admin.listReports();
  }

  @Patch('reports/:id')
  @RequirePermission(AdminPermissionType.MODERATE_CONTENT)
  resolveReport(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ResolveReportDto,
  ) {
    return this.admin.resolveReport(actor, id, dto);
  }

  @Delete('reports/:id')
  @RequirePermission(AdminPermissionType.MODERATE_CONTENT)
  deleteReport(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.deleteReport(actor, id);
  }

  @Get('messages')
  @RequirePermission(AdminPermissionType.MODERATE_CONTENT)
  listDeletedMessages() {
    return this.admin.listDeletedMessages();
  }

  @Delete('messages/:id')
  @RequirePermission(AdminPermissionType.MODERATE_CONTENT)
  deleteMessage(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.admin.deleteChatMessage(actor, id);
  }

  @Get('stats')
  @RequirePermission(AdminPermissionType.VIEW_STATS)
  stats() {
    return this.admin.statsOverview();
  }

  @Get('security')
  @RequirePermission(AdminPermissionType.VIEW_SECURITY)
  security() {
    return this.admin.securityOverview();
  }
}
