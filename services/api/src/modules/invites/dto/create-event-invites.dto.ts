import {
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { EventInviteTargetType } from '../../../common/enums';

export class CreateEventInvitesDto {
  @IsEnum(EventInviteTargetType)
  targetType!: EventInviteTargetType;

  @IsUUID()
  targetId!: string;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  friendIds?: string[];

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  userIds?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MinLength(2, { each: true })
  @MaxLength(32, { each: true })
  pseudos?: string[];
}
