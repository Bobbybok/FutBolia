export enum UserStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  BANNED = 'banned',
  DELETED = 'deleted',
}

export enum GlobalRole {
  USER = 'user',
  SUPER_ADMIN = 'super_admin',
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
