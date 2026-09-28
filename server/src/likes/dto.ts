import { IsIn, IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class ToggleLikeDto {
  @IsIn(['post', 'comment'])
  targetType!: 'post' | 'comment';

  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  targetId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  userId!: string;
}
