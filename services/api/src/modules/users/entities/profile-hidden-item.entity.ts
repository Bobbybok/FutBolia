import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { ProfileHiddenItemType } from '../../../common/enums';
import { User } from './user.entity';

@Entity('profile_hidden_items')
@Unique(['userId', 'itemType', 'itemId'])
export class ProfileHiddenItem {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'item_type', type: 'varchar', length: 24 })
  itemType!: ProfileHiddenItemType;

  @Column({ name: 'item_id', type: 'uuid' })
  itemId!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
