import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  Min,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';
import { MatchStatus } from '../../../common/enums';

export class UpdateMatchDto {
  @IsOptional()
  @IsDateString()
  scheduledAt?: string | null;

  @IsOptional()
  @IsEnum(MatchStatus)
  status?: MatchStatus;

  @ValidateIf((o: UpdateMatchDto) => o.homeScore !== undefined || o.status === MatchStatus.FINISHED)
  @Type(() => Number)
  @IsInt()
  @Min(0)
  homeScore?: number;

  @ValidateIf((o: UpdateMatchDto) => o.awayScore !== undefined || o.status === MatchStatus.FINISHED)
  @Type(() => Number)
  @IsInt()
  @Min(0)
  awayScore?: number;
}
