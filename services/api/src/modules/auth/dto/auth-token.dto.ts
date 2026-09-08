import { IsString, MinLength } from 'class-validator';

/** Opaque hex token (password reset, e-mail change confirm). */
export class AuthTokenDto {
  @IsString()
  @MinLength(20)
  token!: string;
}
