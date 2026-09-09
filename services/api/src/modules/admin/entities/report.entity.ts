import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { ReportStatus, ReportType } from '../../../common/enums';
import { User } from '../../users/entities/user.entity';

@Entity('reports')
export class Report {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar', length: 32 })
  type!: ReportType;

  @Index()
  @Column({ name: 'target_id', type: 'uuid' })
  targetId!: string;

  @Index()
  @Column({ name: 'reporter_id', type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporter_id' })
  reporter!: User;

  @Column({ type: 'text' })
  reason!: string;

  @Column({ name: 'reason_code', type: 'varchar', length: 32, nullable: true })
  reasonCode!: string | null;

  @Column({ type: 'text', nullable: true })
  comment!: string | null;

  @Column({ type: 'varchar', length: 32, default: ReportStatus.OPEN })
  status!: ReportStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @Column({ name: 'reviewed_by_id', type: 'uuid', nullable: true })
  reviewedById!: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'reviewed_by_id' })
  reviewedBy?: User | null;

  @Column({ name: 'reviewed_at', type: 'timestamptz', nullable: true })
  reviewedAt!: Date | null;
}
