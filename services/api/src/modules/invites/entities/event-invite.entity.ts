import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import {
  EventInviteStatus,
  EventInviteTargetType,
} from '../../../common/enums';
import { User } from '../../users/entities/user.entity';

@Entity('event_invites')
@Unique(['targetType', 'targetId', 'inviteeId'])
export class EventInvite {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'target_type', type: 'varchar', length: 32 })
  targetType!: EventInviteTargetType;

  @Index()
  @Column({ name: 'target_id' })
  targetId!: string;

  @Index()
  @Column({ name: 'inviter_id' })
  inviterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'inviter_id' })
  inviter!: User;

  @Index()
  @Column({ name: 'invitee_id' })
  inviteeId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'invitee_id' })
  invitee!: User;

  @Index()
  @Column({ type: 'varchar', length: 32, default: EventInviteStatus.PENDING })
  status!: EventInviteStatus;

  @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
  respondedAt!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
