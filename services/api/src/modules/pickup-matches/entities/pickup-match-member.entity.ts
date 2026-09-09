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
import { PickupMatchSide } from '../../../common/enums';
import { User } from '../../users/entities/user.entity';
import { PickupMatch } from './pickup-match.entity';

@Entity('pickup_match_members')
@Unique(['matchId', 'userId'])
export class PickupMatchMember {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'match_id' })
  matchId!: string;

  @ManyToOne(() => PickupMatch, (match) => match.members, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'match_id' })
  match!: PickupMatch;

  @Index()
  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ type: 'varchar' })
  side!: PickupMatchSide;

  @CreateDateColumn({ name: 'joined_at', type: 'timestamptz' })
  joinedAt!: Date;
}
