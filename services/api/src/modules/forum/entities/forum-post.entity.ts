import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Tournament } from '../../tournaments/entities/tournament.entity';
import { User } from '../../users/entities/user.entity';
import { ForumReply } from './forum-reply.entity';

@Entity('forum_posts')
export class ForumPost {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'tournament_id' })
  tournamentId!: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Index()
  @Column({ name: 'author_id' })
  authorId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author!: User;

  @Column({ length: 160 })
  title!: string;

  @Column({ type: 'text' })
  body!: string;

  @OneToMany(() => ForumReply, (reply) => reply.post)
  replies?: ForumReply[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
