import { IsBoolean, IsEnum, IsUUID } from 'class-validator';
import { ProfileHiddenItemType } from '../../../common/enums';

export class HideCareerItemDto {
  @IsEnum(ProfileHiddenItemType)
  itemType!: ProfileHiddenItemType;

  @IsUUID()
  itemId!: string;

  @IsBoolean()
  hidden!: boolean;
}
