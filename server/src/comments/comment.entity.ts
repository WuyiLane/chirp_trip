import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/// 一条评论。postId 对应 App 里 Mock.posts 的 id（p1、p2……），
/// 作者信息直接冗余存一份：这个项目还没有用户表。
@Entity('comments')
export class Comment {
  @PrimaryGeneratedColumn()
  id!: number;

  @Index()
  @Column({ length: 64 })
  postId!: string;

  @Column({ length: 64 })
  userId!: string;

  @Column({ length: 64 })
  userName!: string;

  @Column({ length: 255, default: '' })
  userAvatar!: string;

  @Column({ type: 'varchar', length: 500 })
  content!: string;

  @Column({ default: 0 })
  likes!: number;

  @CreateDateColumn()
  createdAt!: Date;
}
