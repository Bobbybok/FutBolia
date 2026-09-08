import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { PlayerPosition, StrongFoot } from '../../../common/enums';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(32)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message: 'le pseudo ne doit contenir que des lettres, chiffres et underscores',
  })
  pseudo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  firstName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string | null;

  @IsOptional()
  @IsEnum(PlayerPosition)
  position?: PlayerPosition | null;

  @IsOptional()
  @IsEnum(StrongFoot)
  strongFoot?: StrongFoot | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  level?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string | null;
}
