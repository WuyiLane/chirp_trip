import { Body, Controller, Get, Post, Query } from '@nestjs/common';

import { ToggleLikeDto } from './dto';
import { LikesService } from './likes.service';

@Controller('likes')
export class LikesController {
  constructor(private readonly service: LikesService) {}

  /// GET /api/likes?targetType=post&targetId=p1&userId=me
  @Get()
  status(
    @Query('targetType') targetType: 'post' | 'comment',
    @Query('targetId') targetId: string,
    @Query('userId') userId: string,
  ) {
    return this.service.status(targetType, targetId, userId);
  }

  /// POST /api/likes/toggle
  @Post('toggle')
  toggle(@Body() dto: ToggleLikeDto) {
    return this.service.toggle(dto);
  }
}
