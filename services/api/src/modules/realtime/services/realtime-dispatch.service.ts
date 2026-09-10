import { Injectable, Logger } from '@nestjs/common';
import { Server } from 'socket.io';
import { NotificationsService } from '../../notifications/notifications.service';
import { NotifyUserInput } from '../realtime-events';
import { ConnectionRegistryService } from './connection-registry.service';

@Injectable()
export class RealtimeDispatchService {
  private readonly logger = new Logger(RealtimeDispatchService.name);
  private server: Server | null = null;

  constructor(
    private readonly registry: ConnectionRegistryService,
    private readonly notifications: NotificationsService,
  ) {}

  attach(server: Server) {
    this.server = server;
  }

  userRoom(userId: string) {
    return `user:${userId}`;
  }

  tournamentRoom(tournamentId: string) {
    return `tournament:${tournamentId}`;
  }

  teamRoom(teamId: string) {
    return `team:${teamId}`;
  }

  interTeamRoom(tournamentId: string) {
    return `interTeam:${tournamentId}`;
  }

  pickupRoom(matchId: string) {
    return `pickup:${matchId}`;
  }

  lobbyRoom() {
    return 'lobby';
  }

  emitToRoom(room: string, event: string, payload: unknown) {
    this.server?.to(room).emit(event, payload);
  }

  async notifyUsers(
    userIds: Iterable<string>,
    event: string,
    payload: unknown,
  ) {
    const unique = [...new Set([...userIds].filter(Boolean))];
    await Promise.all(
      unique.map((userId) =>
        this.notifyUser({
          userId,
          event,
          payload,
          skipPush: true,
        }),
      ),
    );
  }

  /**
   * Always push to an open socket (the UI is listening).
   * FCM only when the user has no foreground socket — never skip the live event
   * just because the tab was marked "background" (common on Flutter web).
   */
  async notifyUser(input: NotifyUserInput) {
    const { userId, event, payload } = input;
    if (this.registry.hasSocket(userId)) {
      this.server?.to(this.userRoom(userId)).emit(event, payload);
    }
    if (this.registry.shouldUseSocket(userId) || input.skipPush || !input.push) {
      return;
    }
    try {
      await this.notifications.sendPush(
        userId,
        input.push.title,
        input.push.body,
        input.push.data,
      );
    } catch (err) {
      this.logger.warn(
        `Push failed for ${userId}: ${err instanceof Error ? err.message : err}`,
      );
    }
  }
}
