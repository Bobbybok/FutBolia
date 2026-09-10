import {
  ExperienceLevel,
  FifaPosition,
  PlayerPosition,
} from '../../common/enums';
import { Profile } from './entities/profile.entity';

const FIFA_VALUES = new Set<string>(Object.values(FifaPosition));

export function isFifaPosition(value: string): value is FifaPosition {
  return FIFA_VALUES.has(value);
}

export function fifaToLegacyPosition(code: string): PlayerPosition {
  switch (code) {
    case FifaPosition.GB:
      return PlayerPosition.GK;
    case FifaPosition.DG:
    case FifaPosition.DC:
    case FifaPosition.DD:
      return PlayerPosition.DEF;
    case FifaPosition.MG:
    case FifaPosition.MC:
    case FifaPosition.MD:
    case FifaPosition.MCD:
      return PlayerPosition.MID;
    case FifaPosition.AG:
    case FifaPosition.BU:
    case FifaPosition.AD:
      return PlayerPosition.FWD;
    default:
      return PlayerPosition.ANY;
  }
}

export function legacyPositionToFifa(
  position: string | null | undefined,
): FifaPosition | null {
  switch (position) {
    case PlayerPosition.GK:
    case FifaPosition.GB:
      return FifaPosition.GB;
    case PlayerPosition.DEF:
      return FifaPosition.DC;
    case FifaPosition.DG:
      return FifaPosition.DG;
    case FifaPosition.DC:
      return FifaPosition.DC;
    case FifaPosition.DD:
      return FifaPosition.DD;
    case PlayerPosition.MID:
      return FifaPosition.MC;
    case FifaPosition.MG:
      return FifaPosition.MG;
    case FifaPosition.MC:
      return FifaPosition.MC;
    case FifaPosition.MD:
      return FifaPosition.MD;
    case FifaPosition.MCD:
      return FifaPosition.MCD;
    case PlayerPosition.FWD:
      return FifaPosition.BU;
    case FifaPosition.AG:
      return FifaPosition.AG;
    case FifaPosition.BU:
      return FifaPosition.BU;
    case FifaPosition.AD:
      return FifaPosition.AD;
    default:
      return null;
  }
}

export function normalizePositions(profile: Profile): string[] {
  const raw = profile.positions;
  if (Array.isArray(raw) && raw.length > 0) {
    return raw.filter((code): code is string => typeof code === 'string').slice(0, 5);
  }
  const mapped = legacyPositionToFifa(profile.position);
  return mapped ? [mapped] : [];
}

export function serializeSportProfile(profile: Profile) {
  const positions = normalizePositions(profile);
  return {
    pseudo: profile.pseudo,
    firstName: profile.firstName,
    city: profile.city,
    position: profile.position,
    positions,
    strongFoot: profile.strongFoot,
    heightCm: profile.heightCm,
    weightKg: profile.weightKg,
    experienceLevel: profile.experienceLevel as ExperienceLevel | null,
    playingSinceYear: profile.playingSinceYear,
    availability: Array.isArray(profile.availability) ? profile.availability : [],
    level: profile.level,
    bio: profile.bio,
    avatarUrl: profile.avatarUrl,
  };
}
