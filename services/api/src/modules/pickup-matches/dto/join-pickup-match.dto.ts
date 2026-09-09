import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class JoinPickupMatchDto {
  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(12)
  code?: string;
}
