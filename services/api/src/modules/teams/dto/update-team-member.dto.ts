import { IsEnum } from 'class-validator';
import { TeamMemberSlot } from '../../../common/enums';

export class UpdateTeamMemberDto {
  @IsEnum(TeamMemberSlot)
  slot!: TeamMemberSlot;
}
