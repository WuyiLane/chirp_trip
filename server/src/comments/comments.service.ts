import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';

import { Like } from '../likes/like.entity';
import { Comment } from './comment.entity';
import { CreateCommentDto } from './dto';

@Injectable()
export class CommentsService {
  constructor(@InjectRepository(Comment) private readonly repo: Repository<Comment>) {}

  /// 某条帖子的评论，新的在前
  list(postId: string) {
    return this.repo.find({ where: { postId }, order: { id: 'DESC' } });
  }

  count(postId: string) {
    return this.repo.countBy({ postId });
  }

  create(dto: CreateCommentDto) {
    return this.repo.save(this.repo.create({ ...dto, userAvatar: dto.userAvatar ?? '' }));
  }

  /// 只能删自己的：userId 对不上就 403
  async remove(id: number, userId: string) {
    const found = await this.repo.findOneBy({ id });
    if (!found) throw new NotFoundException('评论不存在');
    if (found.userId !== userId) throw new ForbiddenException('只能删除自己的评论');
    await this.repo.delete(id);
    // 这条评论收到的赞一起删，免得 likes 表里留下没主的记录
    await this.repo.manager.delete(Like, { targetType: 'comment', targetId: String(id) });
  }

  /// 清空某个人发过的所有评论（设置页那个「删除我的评论」），连同这些评论收到的赞
  async removeAllOf(userId: string) {
    const mine = await this.repo.find({ where: { userId }, select: { id: true } });
    if (mine.length === 0) return 0;
    const ids = mine.map((c) => c.id);
    await this.repo.delete({ id: In(ids) });
    await this.repo.manager.delete(Like, { targetType: 'comment', targetId: In(ids.map(String)) });
    return ids.length;
  }
}
