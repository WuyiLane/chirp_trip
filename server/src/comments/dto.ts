import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateCommentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  postId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  userId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  userName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  userAvatar?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  content!: string;
}
