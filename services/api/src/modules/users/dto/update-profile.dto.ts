import {
  ArrayMaxSize,
  IsArray,
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
import {
  AvailabilitySlot,
  ExperienceLevel,
  FifaPosition,
  PlayerPosition,
  StrongFoot,
} from '../../../common/enums';

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
  @IsArray()
  @ArrayMaxSize(5)
  @IsEnum(FifaPosition, { each: true })
  positions?: FifaPosition[];

  @IsOptional()
  @IsEnum(StrongFoot)
  strongFoot?: StrongFoot | null;

  @IsOptional()
  @IsInt()
  @Min(120)
  @Max(230)
  heightCm?: number | null;

  @IsOptional()
  @IsInt()
  @Min(40)
  @Max(160)
  weightKg?: number | null;

  @IsOptional()
  @IsEnum(ExperienceLevel)
  experienceLevel?: ExperienceLevel | null;

  @IsOptional()
  @IsInt()
  @Min(1970)
  @Max(2035)
  playingSinceYear?: number | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @IsEnum(AvailabilitySlot, { each: true })
  availability?: AvailabilitySlot[];

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
