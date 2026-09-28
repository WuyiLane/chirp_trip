import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, Unique } from 'typeorm';

/// 一次点赞。targetType 区分点的是帖子还是评论，targetId 是对应的 id。
/// 同一个人对同一个目标只能有一条，所以加了联合唯一索引。
@Entity('likes')
@Unique('uniq_like', ['targetType', 'targetId', 'userId'])
export class Like {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 16 })
  targetType!: 'post' | 'comment';

  @Column({ length: 64 })
  targetId!: string;

  @Column({ length: 64 })
  userId!: string;

  @CreateDateColumn()
  createdAt!: Date;
}
