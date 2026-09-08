import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateForumPostDto {
  @IsString()
  @MinLength(3)
  @MaxLength(160)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  body!: string;
}
