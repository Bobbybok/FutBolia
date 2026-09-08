import {
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';
import {
  AdminPermissionType,
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
}

export class CreateReportDto {
  @IsEnum(ReportType)
  type!: ReportType;

  @IsUUID()
  targetId!: string;

  @IsString()
  @MinLength(3)
  reason!: string;
}
