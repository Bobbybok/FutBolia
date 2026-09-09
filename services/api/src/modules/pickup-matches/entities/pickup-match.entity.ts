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
import {
  PickupMatchStatus,
  TournamentVisibility,
} from '../../../common/enums';
import { User } from '../../users/entities/user.entity';
import { PickupMatchMember } from './pickup-match-member.entity';

@Entity('pickup_matches')
export class PickupMatch {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'players_per_team', type: 'int' })
  playersPerTeam!: number;

  @Column({ name: 'scheduled_at', type: 'timestamptz' })
  scheduledAt!: Date;

  @Column({ length: 160 })
  location!: string;

  @Column({ type: 'varchar', default: TournamentVisibility.PUBLIC })
  visibility!: TournamentVisibility;

  @Index({ unique: true, where: '"join_code" IS NOT NULL' })
  @Column({ name: 'join_code', type: 'varchar', length: 12, nullable: true })
  joinCode!: string | null;

  @Column({ type: 'varchar', default: PickupMatchStatus.OPEN })
  status!: PickupMatchStatus;

  @Column({ name: 'home_score', type: 'int', nullable: true })
  homeScore!: number | null;

  @Column({ name: 'away_score', type: 'int', nullable: true })
  awayScore!: number | null;

  @Column({ name: 'created_by_id' })
  createdById!: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_id' })
  createdBy!: User;

  @OneToMany(() => PickupMatchMember, (member) => member.match)
  members?: PickupMatchMember[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
