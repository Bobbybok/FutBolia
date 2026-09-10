import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import {
  AdminPermissionType,
  AvailabilitySlot,
  ExperienceLevel,
  FifaPosition,
  MatchStatus,
  PickupMatchStatus,
  ReportReasonCode,
  ReportStatus,
  ReportType,
  StrongFoot,
  TeamStatus,
  TournamentMode,
  TournamentStatus,
  TournamentVisibility,
} from '../../../common/enums';

export class GrantAdminDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayUnique()
  @IsEnum(AdminPermissionType, { each: true })
  permissions!: AdminPermissionType[];
}

export class GrantModeratorDto {
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsEnum(AdminPermissionType, { each: true })
  permissions?: AdminPermissionType[];
}

export class UpdateAdminPermissionsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayUnique()
  @IsEnum(AdminPermissionType, { each: true })
  permissions!: AdminPermissionType[];
}

export class AdminUserQueryDto {
  @IsOptional()
  @IsString()
  q?: string;
}

export class BanUserDto {
  @IsOptional()
  @IsString()
  reason?: string;
}

export class PatchAdminUserDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(32)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message:
      'le pseudo ne doit contenir que des lettres, chiffres et underscores',
  })
  pseudo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  firstName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsEnum(FifaPosition, { each: true })
  positions?: FifaPosition[];

  @IsOptional()
  @IsEnum(StrongFoot)
  strongFoot?: StrongFoot | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(120)
  @Max(230)
  heightCm?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(40)
  @Max(160)
  weightKg?: number | null;

  @IsOptional()
  @IsEnum(ExperienceLevel)
  experienceLevel?: ExperienceLevel | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1970)
  @Max(2035)
  playingSinceYear?: number | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @IsEnum(AvailabilitySlot, { each: true })
  availability?: AvailabilitySlot[];

  @IsOptional()
  @IsBoolean()
  clearAvatar?: boolean;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password?: string;
}

export class PatchTournamentDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  location?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2)
  @Max(64)
  maxTeams?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(11)
  startersCount?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(11)
  substitutesCount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  rulesText?: string | null;

  @IsOptional()
  @IsEnum(TournamentMode)
  mode?: TournamentMode;

  @IsOptional()
  @IsEnum(TournamentVisibility)
  visibility?: TournamentVisibility;

  @IsOptional()
  @IsEnum(TournamentStatus)
  status?: TournamentStatus;

  @IsOptional()
  @IsBoolean()
  clearCover?: boolean;
}

export class PatchAdminMatchDto {
  @IsOptional()
  @IsDateString()
  scheduledAt?: string | null;

  @IsOptional()
  @IsEnum(MatchStatus)
  status?: MatchStatus;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  homeScore?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  awayScore?: number | null;
}

export class PatchAdminTeamDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsEnum(TeamStatus)
  status?: TeamStatus;
}

export class PatchAdminPickupDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  location?: string;

  @IsOptional()
  @IsDateString()
  scheduledAt?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(11)
  playersPerTeam?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  homeScore?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  awayScore?: number | null;

  @IsOptional()
  @IsEnum(PickupMatchStatus)
  status?: PickupMatchStatus;
}

export class TransferOwnerDto {
  @IsUUID()
  userId!: string;
}

export class ForceTeamStatusDto {
  @IsEnum(TeamStatus)
  status!: TeamStatus;
}

export class ResolveReportDto {
  @IsEnum(ReportStatus)
  status!: ReportStatus;

  @IsOptional()
  @IsIn(['none', 'timeout', 'ban'])
  action?: 'none' | 'timeout' | 'ban';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(90 * 24 * 60)
  timeoutMinutes?: number;

  @IsOptional()
  @IsBoolean()
  deleteMessage?: boolean;
}

export class TimeoutUserDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(90 * 24 * 60)
  minutes!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  reason?: string;
}

export class CreateReportDto {
  @IsEnum(ReportType)
  type!: ReportType;

  @IsUUID()
  targetId!: string;

  @IsEnum(ReportReasonCode)
  reasonCode!: ReportReasonCode;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;
}
