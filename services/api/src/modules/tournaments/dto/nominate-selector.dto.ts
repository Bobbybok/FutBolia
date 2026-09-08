import { IsUUID } from 'class-validator';

export class NominateSelectorDto {
  @IsUUID()
  userId!: string;
}
