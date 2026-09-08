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
import { RecruitmentOfferStatus } from '../../../common/enums';
import { Tournament } from '../../tournaments/entities/tournament.entity';
import { Team } from '../../teams/entities/team.entity';
import { User } from '../../users/entities/user.entity';

@Entity('recruitment_offers')
export class RecruitmentOffer {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'tournament_id' })
  tournamentId!: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Index()
  @Column({ name: 'team_id' })
  teamId!: string;

  @ManyToOne(() => Team, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'team_id' })
  team!: Team;

  @Index()
  @Column({ name: 'player_id' })
  playerId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'player_id' })
  player!: User;

  @Column({ name: 'selector_id' })
  selectorId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'selector_id' })
  selector!: User;

  @Column({ type: 'varchar', default: RecruitmentOfferStatus.PENDING })
  status!: RecruitmentOfferStatus;

  @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
  resolvedAt!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
