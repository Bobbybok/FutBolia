import { IsUUID } from 'class-validator';

export class SetCaptainDto {
  @IsUUID()
  userId!: string;
}
