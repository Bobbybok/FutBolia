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
import { TeamMember } from './team-member.entity';
import { TeamStatus } from '../../../common/enums';

@Entity('teams')
export class Team {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'tournament_id' })
  tournamentId!: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Column({ length: 80 })
  name!: string;

  @Column({ name: 'logo_url', type: 'varchar', nullable: true })
  logoUrl!: string | null;

  @Column({ type: 'varchar', default: TeamStatus.FORMING })
  status!: TeamStatus;

  @Column({ name: 'captain_id', type: 'uuid', nullable: true })
  captainId!: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'captain_id' })
  captain?: User | null;

  @Column({ name: 'selector_id', type: 'uuid', nullable: true })
  selectorId!: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'selector_id' })
  selector?: User | null;

  @Column({ name: 'created_by_id' })
  createdById!: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_id' })
  createdBy!: User;

  @OneToMany(() => TeamMember, (member) => member.team)
  members?: TeamMember[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
