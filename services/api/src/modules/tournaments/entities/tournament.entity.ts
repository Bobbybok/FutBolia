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
  TournamentMode,
  TournamentStatus,
  TournamentVisibility,
} from '../../../common/enums';
import { User } from '../../users/entities/user.entity';
import { TournamentMember } from './tournament-member.entity';

@Entity('tournaments')
export class Tournament {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ length: 120 })
  name!: string;

  @Column({ type: 'varchar', nullable: true })
  imageUrl!: string | null;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ name: 'starts_at', type: 'timestamptz' })
  startsAt!: Date;

  @Column({ length: 160 })
  location!: string;

  @Column({ name: 'max_teams', type: 'int' })
  maxTeams!: number;

  @Column({ name: 'starters_count', type: 'int', default: 5 })
  startersCount!: number;

  @Column({ name: 'substitutes_count', type: 'int', default: 2 })
  substitutesCount!: number;

  @Column({ name: 'rules_text', type: 'text', nullable: true })
  rulesText!: string | null;

  @Column({ type: 'varchar', default: TournamentMode.CLASSIC })
  mode!: TournamentMode;

  @Column({ type: 'varchar', default: TournamentVisibility.PUBLIC })
  visibility!: TournamentVisibility;

  @Index({ unique: true, where: '"join_code" IS NOT NULL' })
  @Column({ name: 'join_code', type: 'varchar', length: 12, nullable: true })
  joinCode!: string | null;

  @Column({ name: 'join_code_enabled', type: 'boolean', default: true })
  joinCodeEnabled!: boolean;

  @Column({ type: 'varchar', default: TournamentStatus.REGISTRATION_OPEN })
  status!: TournamentStatus;

  @Column({ name: 'created_by_id' })
  createdById!: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_id' })
  createdBy!: User;

  @OneToMany(() => TournamentMember, (member) => member.tournament)
  members?: TournamentMember[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
