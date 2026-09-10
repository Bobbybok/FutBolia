import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import {
  ExperienceLevel,
  PlayerPosition,
  StrongFoot,
} from '../../../common/enums';
import { User } from './user.entity';

@Entity('profiles')
export class Profile {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', unique: true })
  userId!: string;

  @OneToOne(() => User, (user) => user.profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ unique: true, length: 32 })
  pseudo!: string;

  @Column({ name: 'first_name', type: 'varchar', length: 80, nullable: true })
  firstName!: string | null;

  @Column({ type: 'varchar', length: 80, nullable: true })
  city!: string | null;

  @Column({ type: 'varchar', length: 16, nullable: true })
  position!: PlayerPosition | null;

  @Column({ type: 'jsonb', default: () => "'[]'" })
  positions!: string[];

  @Column({ name: 'strong_foot', type: 'varchar', length: 16, nullable: true })
  strongFoot!: StrongFoot | null;

  @Column({ name: 'height_cm', type: 'smallint', nullable: true })
  heightCm!: number | null;

  @Column({ name: 'weight_kg', type: 'smallint', nullable: true })
  weightKg!: number | null;

  @Column({ name: 'experience_level', type: 'varchar', length: 24, nullable: true })
  experienceLevel!: ExperienceLevel | null;

  @Column({ name: 'playing_since_year', type: 'smallint', nullable: true })
  playingSinceYear!: number | null;

  @Column({ type: 'jsonb', default: () => "'[]'" })
  availability!: string[];

  @Column({ type: 'smallint', nullable: true })
  level!: number | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  bio!: string | null;

  @Column({ name: 'avatar_url', type: 'varchar', nullable: true })
  avatarUrl!: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
