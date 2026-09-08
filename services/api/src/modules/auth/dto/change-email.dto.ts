import { IsEmail, IsString, MinLength } from 'class-validator';

export class ChangeEmailDto {
  @IsEmail()
  newEmail!: string;

  @IsString()
  @MinLength(8)
  password!: string;
}
