import { IsString, Matches } from 'class-validator';

/** 6-digit e-mail verification code. */
export class VerifyEmailDto {
  @IsString()
  @Matches(/^\d{6}$/, {
    message: 'le code doit contenir exactement 6 chiffres',
  })
  token!: string;
}
