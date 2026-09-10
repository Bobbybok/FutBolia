import { IsEnum, IsOptional, IsUUID, ValidateIf } from 'class-validator';
import { FifaPosition, TeamMemberSlot } from '../../../common/enums';

export class AddTeamMemberDto {
  @IsUUID()
  userId!: string;

  @IsOptional()
  @IsEnum(TeamMemberSlot)
  slot?: TeamMemberSlot;

  @ValidateIf((_, value) => value != null)
  @IsEnum(FifaPosition)
  position?: FifaPosition | null;
}
