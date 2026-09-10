import { IsEnum, IsOptional, IsUUID, ValidateIf } from 'class-validator';
import { FifaPosition, TeamMemberSlot } from '../../../common/enums';

export class AssignTeamDto {
  @IsUUID()
  userId!: string;

  /** `null` = retirer de l’équipe (reste inscrit au tournoi). */
  @ValidateIf((_, value) => value != null)
  @IsUUID()
  teamId?: string | null;

  @IsOptional()
  @IsEnum(TeamMemberSlot)
  slot?: TeamMemberSlot;

  @ValidateIf((_, value) => value != null)
  @IsEnum(FifaPosition)
  position?: FifaPosition | null;
}
