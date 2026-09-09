import { ArrayMinSize, IsArray, IsEnum, IsUUID } from 'class-validator';
import { EventInviteTargetType } from '../../../common/enums';

export class CreateEventInvitesDto {
  @IsEnum(EventInviteTargetType)
  targetType!: EventInviteTargetType;

  @IsUUID()
  targetId!: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsUUID('4', { each: true })
  friendIds!: string[];
}
