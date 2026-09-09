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
import { TournamentVisibility } from '../../../common/enums';

export class CreatePickupMatchDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(11)
  playersPerTeam!: number;

  @IsDateString()
  scheduledAt!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(160)
  location!: string;

  @IsOptional()
  @IsEnum(TournamentVisibility)
  visibility?: TournamentVisibility;
}
