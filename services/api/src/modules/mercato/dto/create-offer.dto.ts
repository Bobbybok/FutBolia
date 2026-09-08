import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { TeamMemberSlot } from '../../../common/enums';

export class CreateOfferDto {
  @IsUUID()
  teamId!: string;

  @IsUUID()
  playerId!: string;

  @IsOptional()
  @IsEnum(TeamMemberSlot)
  slot?: TeamMemberSlot;
}
