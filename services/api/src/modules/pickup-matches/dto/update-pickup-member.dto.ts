import { IsEnum, IsOptional, ValidateIf } from 'class-validator';
import { PickupMatchSide } from '../../../common/enums';

export class UpdatePickupMemberDto {
  @IsOptional()
  @ValidateIf((_, value) => value != null)
  @IsEnum(PickupMatchSide)
  side?: PickupMatchSide | null;
}
