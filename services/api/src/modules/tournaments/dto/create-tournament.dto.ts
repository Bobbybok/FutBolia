import {
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
  TournamentVisibility,
} from '../../../common/enums';

export class CreateTournamentDto {
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsDateString()
  startsAt!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(160)
  location!: string;

  @Type(() => Number)
  @IsInt()
  @Min(2)
  @Max(64)
  maxTeams!: number;

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
  rulesText?: string;

  @IsOptional()
  @IsEnum(TournamentMode)
  mode?: TournamentMode;

  @IsOptional()
  @IsEnum(TournamentVisibility)
  visibility?: TournamentVisibility;
}
