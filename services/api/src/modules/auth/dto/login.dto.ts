import {
  IsEmail,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class LoginDto {
  @ValidateIf((o: LoginDto) => !o.pseudo?.trim())
  @IsEmail()
  email?: string;

  @ValidateIf((o: LoginDto) => !o.email?.trim())
  @IsString()
  @MinLength(3)
  @MaxLength(32)
  pseudo?: string;

  @IsString()
  @MinLength(8)
  password!: string;
}
