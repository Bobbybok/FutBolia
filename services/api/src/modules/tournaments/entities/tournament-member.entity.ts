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
import { TournamentMemberRole } from '../../../common/enums';
import { User } from '../../users/entities/user.entity';
import { Tournament } from './tournament.entity';

@Entity('tournament_members')
@Unique(['tournamentId', 'userId'])
export class TournamentMember {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'tournament_id' })
  tournamentId!: string;

  @ManyToOne(() => Tournament, (tournament) => tournament.members, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Index()
  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ type: 'varchar', default: TournamentMemberRole.PLAYER })
  role!: TournamentMemberRole;

  @CreateDateColumn({ name: 'joined_at', type: 'timestamptz' })
  joinedAt!: Date;
}
