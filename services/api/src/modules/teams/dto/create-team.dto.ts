import { IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreateTeamDto {
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  logoUrl?: string;

  /** Mode Sélection : sélectionneur assigné à l’équipe. */
  @IsOptional()
  @IsUUID()
  selectorId?: string;
}
