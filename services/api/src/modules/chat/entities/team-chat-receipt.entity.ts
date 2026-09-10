import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Team } from '../../teams/entities/team.entity';

@Entity('team_chat_receipts')
@Unique(['teamId', 'userId'])
export class TeamChatReceipt {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'team_id' })
  teamId!: string;

  @ManyToOne(() => Team, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_id' })
  team!: Team;

  @Index()
  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'last_read_at', type: 'timestamptz', nullable: true })
  lastReadAt!: Date | null;

  @Column({ name: 'chat_cleared_at', type: 'timestamptz', nullable: true })
  chatClearedAt!: Date | null;

  @Column({ name: 'chat_hidden_at', type: 'timestamptz', nullable: true })
  chatHiddenAt!: Date | null;
}
