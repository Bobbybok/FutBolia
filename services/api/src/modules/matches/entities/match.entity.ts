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
import { MatchStatus } from '../../../common/enums';
import { Tournament } from '../../tournaments/entities/tournament.entity';
import { Team } from '../../teams/entities/team.entity';
import { User } from '../../users/entities/user.entity';

@Entity('matches')
export class Match {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'tournament_id' })
  tournamentId!: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Column({ name: 'home_team_id' })
  homeTeamId!: string;

  @ManyToOne(() => Team, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'home_team_id' })
  homeTeam!: Team;

  @Column({ name: 'away_team_id' })
  awayTeamId!: string;

  @ManyToOne(() => Team, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'away_team_id' })
  awayTeam!: Team;

  @Column({ name: 'scheduled_at', type: 'timestamptz', nullable: true })
  scheduledAt!: Date | null;

  @Column({ type: 'varchar', default: MatchStatus.SCHEDULED })
  status!: MatchStatus;

  @Column({ name: 'home_score', type: 'int', nullable: true })
  homeScore!: number | null;

  @Column({ name: 'away_score', type: 'int', nullable: true })
  awayScore!: number | null;

  @Column({ name: 'created_by_id' })
  createdById!: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_id' })
  createdBy!: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
