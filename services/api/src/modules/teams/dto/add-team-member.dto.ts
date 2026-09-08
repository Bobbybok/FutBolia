import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { TeamMemberSlot } from '../../../common/enums';

export class AddTeamMemberDto {
  @IsUUID()
  userId!: string;

  @IsOptional()
  @IsEnum(TeamMemberSlot)
  slot?: TeamMemberSlot;
}
