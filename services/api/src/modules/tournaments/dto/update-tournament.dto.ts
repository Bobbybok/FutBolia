import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import {
  TournamentMode,
  TournamentStatus,
  TournamentVisibility,
} from '../../../common/enums';

export class UpdateTournamentDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
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
  joinCodeEnabled?: boolean;
}
