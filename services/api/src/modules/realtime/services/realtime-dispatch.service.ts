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

  emitToRoom(room: string, event: string, payload: unknown) {
    this.server?.to(room).emit(event, payload);
  }

  /**
   * Socket if the user has a foreground connection; otherwise FCM.
   * Never both for the same event.
   */
  async notifyUser(input: NotifyUserInput) {
    const { userId, event, payload } = input;
    if (this.registry.shouldUseSocket(userId)) {
      this.server?.to(this.userRoom(userId)).emit(event, payload);
      return;
    }
    if (input.skipPush || !input.push) {
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
