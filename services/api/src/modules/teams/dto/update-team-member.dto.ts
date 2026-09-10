import { IsEnum, IsOptional, ValidateIf } from 'class-validator';
import { FifaPosition, TeamMemberSlot } from '../../../common/enums';

export class UpdateTeamMemberDto {
  @IsOptional()
  @IsEnum(TeamMemberSlot)
  slot?: TeamMemberSlot;

  @IsOptional()
  @ValidateIf((_, value) => value != null)
  @IsEnum(FifaPosition)
  position?: FifaPosition | null;
}
