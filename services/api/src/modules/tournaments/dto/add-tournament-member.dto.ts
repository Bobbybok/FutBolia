import { IsUUID } from 'class-validator';

export class AddTournamentMemberDto {
  @IsUUID()
  userId!: string;
}
