import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { ForumPost } from './forum-post.entity';

@Entity('forum_replies')
export class ForumReply {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'post_id' })
  postId!: string;

  @ManyToOne(() => ForumPost, (post) => post.replies, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'post_id' })
  post!: ForumPost;

  @Index()
  @Column({ name: 'author_id' })
  authorId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author!: User;

  @Column({ type: 'text' })
  body!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
