import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { PickupMatchSide } from '../../../common/enums';

export class AddPickupMemberDto {
  @IsUUID()
  userId!: string;

  @IsOptional()
  @IsEnum(PickupMatchSide)
  side?: PickupMatchSide;
}
