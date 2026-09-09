export enum UserStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  BANNED = 'banned',
  DELETED = 'deleted',
}

export enum GlobalRole {
  USER = 'user',
  MODERATOR = 'moderator',
  ADMIN = 'admin',
  /** @deprecated Use ADMIN. Kept so existing DB rows still load. */
  SUPER_ADMIN = 'super_admin',
}

export enum AdminPermissionType {
  MANAGE_USERS = 'manage_users',
  MANAGE_TOURNAMENTS = 'manage_tournaments',
  MODERATE_CONTENT = 'moderate_content',
  VIEW_SECURITY = 'view_security',
  VIEW_STATS = 'view_stats',
  MANAGE_ADMINS = 'manage_admins',
  MANAGE_MODERATORS = 'manage_moderators',
}

export const ALL_ADMIN_PERMISSIONS = Object.values(AdminPermissionType);

export enum ReportType {
  MESSAGE = 'message',
  USER = 'user',
  TOURNAMENT = 'tournament',
}

export enum ReportStatus {
  OPEN = 'open',
  REVIEWED = 'reviewed',
  DISMISSED = 'dismissed',
}

export type PlatformRole = 'user' | 'moderator' | 'admin';

export function toPlatformRole(globalRole: string | undefined): PlatformRole {
  if (globalRole === GlobalRole.ADMIN || globalRole === GlobalRole.SUPER_ADMIN) {
    return 'admin';
  }
  if (globalRole === GlobalRole.MODERATOR) {
    return 'moderator';
  }
  return 'user';
}

export function isPlatformAdmin(globalRole: string | undefined): boolean {
  return toPlatformRole(globalRole) === 'admin';
}

export function isStaff(globalRole: string | undefined): boolean {
  const role = toPlatformRole(globalRole);
  return role === 'admin' || role === 'moderator';
}

export function displayPseudo(
  pseudo: string | null | undefined,
  globalRole: string | undefined,
): string {
  const name = (pseudo ?? '').trim() || 'Joueur';
  const role = toPlatformRole(globalRole);
  if (role === 'admin') return `${name} (admin)`;
  if (role === 'moderator') return `${name} (modo)`;
  return name;
}

export enum AuthTokenType {
  EMAIL_VERIFY = 'email_verify',
  PASSWORD_RESET = 'password_reset',
  EMAIL_CHANGE = 'email_change',
}

export enum PlayerPosition {
  GK = 'gk',
  DEF = 'def',
  MID = 'mid',
  FWD = 'fwd',
  ANY = 'any',
}

export enum StrongFoot {
  LEFT = 'left',
  RIGHT = 'right',
  BOTH = 'both',
}

export enum TournamentMode {
  CLASSIC = 'classic',
  SELECTION = 'selection',
}

export enum TournamentVisibility {
  PUBLIC = 'public',
  PRIVATE = 'private',
}

export enum TournamentStatus {
  DRAFT = 'draft',
  REGISTRATION_OPEN = 'registration_open',
  REGISTRATION_CLOSED = 'registration_closed',
  IN_PROGRESS = 'in_progress',
  FINISHED = 'finished',
  CANCELLED = 'cancelled',
}

export enum TournamentMemberRole {
  ORGANIZER = 'organizer',
  SELECTOR = 'selector',
  CAPTAIN = 'captain',
  PLAYER = 'player',
}

export enum TeamMemberSlot {
  STARTER = 'starter',
  SUBSTITUTE = 'substitute',
}

export enum TeamStatus {
  FORMING = 'forming',
  COMPLETE = 'complete',
  VALIDATED = 'validated',
}

export enum RecruitmentOfferStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  CANCELLED = 'cancelled',
}

export enum MercatoPlayerStatus {
  AVAILABLE = 'available',
  OFFER_SENT = 'offer_sent',
  IN_NEGOTIATION = 'in_negotiation',
  RECRUITED = 'recruited',
  UNAVAILABLE = 'unavailable',
}

export enum MatchStatus {
  SCHEDULED = 'scheduled',
  FINISHED = 'finished',
  CANCELLED = 'cancelled',
}

export enum PickupMatchStatus {
  OPEN = 'open',
  FULL = 'full',
  FINISHED = 'finished',
  CANCELLED = 'cancelled',
}

export enum PickupMatchSide {
  HOME = 'home',
  AWAY = 'away',
}

export enum FriendRequestStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
}

export enum EventInviteTargetType {
  TOURNAMENT = 'tournament',
  PICKUP_MATCH = 'pickup_match',
}

export enum EventInviteStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
  CANCELLED = 'cancelled',
}
