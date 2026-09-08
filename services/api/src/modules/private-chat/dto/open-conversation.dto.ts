import { IsUUID } from 'class-validator';

export class OpenConversationDto {
  @IsUUID()
  friendId!: string;
}
