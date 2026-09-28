import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Query } from '@nestjs/common';

import { CommentsService } from './comments.service';
import { CreateCommentDto } from './dto';

@Controller('comments')
export class CommentsController {
  constructor(private readonly service: CommentsService) {}

  /// GET /api/comments?postId=p1
  @Get()
  list(@Query('postId') postId: string) {
    return this.service.list(postId);
  }

  /// GET /api/comments/count?postId=p1
  @Get('count')
  async count(@Query('postId') postId: string) {
    return { count: await this.service.count(postId) };
  }

  /// POST /api/comments
  @Post()
  create(@Body() dto: CreateCommentDto) {
    return this.service.create(dto);
  }

  /// DELETE /api/comments/12?userId=me
  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number, @Query('userId') userId: string) {
    await this.service.remove(id, userId);
    return { ok: true };
  }

  /// DELETE /api/comments?userId=me —— 清空我发过的所有评论
  @Delete()
  async removeMine(@Query('userId') userId: string) {
    return { deleted: await this.service.removeAllOf(userId) };
  }
}
