import { IsOptional, IsString, IsUUID, MinLength } from 'class-validator';

export class SendFriendRequestDto {
  @IsOptional()
  @IsUUID()
  userId?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  pseudo?: string;
}
