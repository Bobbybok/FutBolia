import {
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
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
  ReportReasonCode,
  ReportStatus,
  ReportType,
  TeamStatus,
  TournamentStatus,
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
  @MinLength(8)
  @MaxLength(72)
  password?: string;
}

export class PatchTournamentDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  name?: string;

  @IsOptional()
  @IsEnum(TournamentStatus)
  status?: TournamentStatus;
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
