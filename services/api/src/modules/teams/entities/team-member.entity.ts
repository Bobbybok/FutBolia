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
import { TeamMemberSlot } from '../../../common/enums';
import { User } from '../../users/entities/user.entity';
import { Team } from './team.entity';

@Entity('team_members')
@Unique(['teamId', 'userId'])
export class TeamMember {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'team_id' })
  teamId!: string;

  @ManyToOne(() => Team, (team) => team.members, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_id' })
  team!: Team;

  @Index()
  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ type: 'varchar', default: TeamMemberSlot.STARTER })
  slot!: TeamMemberSlot;

  @CreateDateColumn({ name: 'joined_at', type: 'timestamptz' })
  joinedAt!: Date;
}
