import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { ToggleLikeDto } from './dto';
import { Like } from './like.entity';

@Injectable()
export class LikesService {
  constructor(@InjectRepository(Like) private readonly repo: Repository<Like>) {}

  /// 某个目标的点赞数 + 我有没有点过
  async status(targetType: 'post' | 'comment', targetId: string, userId: string) {
    const [count, mine] = await Promise.all([
      this.repo.countBy({ targetType, targetId }),
      this.repo.findOneBy({ targetType, targetId, userId }),
    ]);
    return { count, liked: mine != null };
  }

  /// 点过就取消，没点过就点上，返回最新状态
  async toggle(dto: ToggleLikeDto) {
    const found = await this.repo.findOneBy(dto);
    if (found) {
      await this.repo.delete(found.id);
    } else {
      await this.repo.save(this.repo.create(dto));
    }
    return this.status(dto.targetType, dto.targetId, dto.userId);
  }
}
