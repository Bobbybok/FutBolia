import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { DirectMessage } from './direct-message.entity';

@Entity('conversations')
@Unique(['user1Id', 'user2Id'])
@Check(`"user1_id" < "user2_id"`)
export class Conversation {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'user1_id' })
  user1Id!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user1_id' })
  user1!: User;

  @Index()
  @Column({ name: 'user2_id' })
  user2Id!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user2_id' })
  user2!: User;

  @OneToMany(() => DirectMessage, (message) => message.conversation)
  messages?: DirectMessage[];

  @Column({ name: 'user1_cleared_at', type: 'timestamptz', nullable: true })
  user1ClearedAt!: Date | null;

  @Column({ name: 'user2_cleared_at', type: 'timestamptz', nullable: true })
  user2ClearedAt!: Date | null;

  @Column({ name: 'user1_hidden_at', type: 'timestamptz', nullable: true })
  user1HiddenAt!: Date | null;

  @Column({ name: 'user2_hidden_at', type: 'timestamptz', nullable: true })
  user2HiddenAt!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
