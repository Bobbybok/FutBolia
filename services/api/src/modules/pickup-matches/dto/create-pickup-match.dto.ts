import {
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
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

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @IsOptional()
  @IsEnum(TournamentVisibility)
  visibility?: TournamentVisibility;
}
