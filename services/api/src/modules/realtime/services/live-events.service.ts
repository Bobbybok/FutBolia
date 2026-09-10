import { Inject, Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../../database/database.module';
import { TournamentMember } from '../../tournaments/entities/tournament-member.entity';
import { Tournament } from '../../tournaments/entities/tournament.entity';
import { PickupMatchMember } from '../../pickup-matches/entities/pickup-match-member.entity';
import { PickupMatch } from '../../pickup-matches/entities/pickup-match.entity';
import { RealtimeEvents } from '../realtime-events';
import { RealtimeDispatchService } from './realtime-dispatch.service';

export type LiveExtra = Record<string, unknown>;

@Injectable()
export class LiveEventsService {
  constructor(
    private readonly realtime: RealtimeDispatchService,
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  async tournamentChanged(
    tournamentId: string,
    reason: string,
    extra: LiveExtra = {},
  ) {
    const payload = {
      tournamentId,
      reason,
      at: new Date().toISOString(),
      ...extra,
    };
    this.realtime.emitToRoom(
      this.realtime.tournamentRoom(tournamentId),
      RealtimeEvents.tournamentUpdated,
      payload,
    );
    this.realtime.emitToRoom(this.realtime.lobbyRoom(), RealtimeEvents.lobbyChanged, {
      kind: 'tournament',
      id: tournamentId,
      reason,
    });
    if (!this.dataSource) return;
    const members = await this.dataSource.getRepository(TournamentMember).find({
      where: { tournamentId },
      select: ['userId'],
    });
    const tournament = await this.dataSource.getRepository(Tournament).findOne({
      where: { id: tournamentId },
      select: ['createdById'],
    });
    const ids = new Set(members.map((m) => m.userId));
    if (tournament?.createdById) ids.add(tournament.createdById);
    const actorId = extra.actorId;
    if (typeof actorId === 'string') ids.add(actorId);
    await this.realtime.notifyUsers(
      ids,
      RealtimeEvents.tournamentUpdated,
      payload,
    );
  }

  async pickupChanged(matchId: string, reason: string, extra: LiveExtra = {}) {
    const payload = {
      matchId,
      reason,
      at: new Date().toISOString(),
      ...extra,
    };
    this.realtime.emitToRoom(
      this.realtime.pickupRoom(matchId),
      RealtimeEvents.pickupUpdated,
      payload,
    );
    this.realtime.emitToRoom(this.realtime.lobbyRoom(), RealtimeEvents.lobbyChanged, {
      kind: 'pickup',
      id: matchId,
      reason,
    });
    if (!this.dataSource) return;
    const members = await this.dataSource.getRepository(PickupMatchMember).find({
      where: { matchId },
      select: ['userId'],
    });
    const match = await this.dataSource.getRepository(PickupMatch).findOne({
      where: { id: matchId },
      select: ['createdById'],
    });
    const ids = new Set(members.map((m) => m.userId));
    if (match?.createdById) ids.add(match.createdById);
    const actorId = extra.actorId;
    if (typeof actorId === 'string') ids.add(actorId);
    await this.realtime.notifyUsers(ids, RealtimeEvents.pickupUpdated, payload);
  }
}
