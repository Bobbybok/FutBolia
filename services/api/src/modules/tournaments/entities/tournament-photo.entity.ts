import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Tournament } from './tournament.entity';

@Entity('tournament_photos')
export class TournamentPhoto {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ name: 'tournament_id', type: 'uuid' })
  tournamentId!: string;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Column({ name: 'uploaded_by_id', type: 'uuid' })
  uploadedById!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'uploaded_by_id' })
  uploadedBy!: User;

  @Column({ name: 'mime_type', length: 64 })
  mimeType!: string;

  @Column({ type: 'bytea' })
  data!: Buffer;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
