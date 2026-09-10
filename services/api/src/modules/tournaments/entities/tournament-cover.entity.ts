import {
  Column,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Tournament } from './tournament.entity';

@Entity('tournament_covers')
export class TournamentCover {
  @PrimaryColumn({ name: 'tournament_id', type: 'uuid' })
  tournamentId!: string;

  @OneToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament!: Tournament;

  @Column({ name: 'mime_type', length: 64 })
  mimeType!: string;

  @Column({ type: 'bytea' })
  data!: Buffer;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
