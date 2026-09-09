import { Injectable } from '@nestjs/common';

type SocketPresence = {
  userId: string;
  foreground: boolean;
};

/**
 * In-memory presence. Valid while Render stays on a single instance.
 * Swap the store for Redis when scaling horizontally.
 */
@Injectable()
export class ConnectionRegistryService {
  private readonly sockets = new Map<string, SocketPresence>();
  private readonly userSockets = new Map<string, Set<string>>();

  add(userId: string, socketId: string) {
    this.sockets.set(socketId, { userId, foreground: true });
    let set = this.userSockets.get(userId);
    if (!set) {
      set = new Set();
      this.userSockets.set(userId, set);
    }
    set.add(socketId);
  }

  remove(socketId: string) {
    const presence = this.sockets.get(socketId);
    if (!presence) return;
    this.sockets.delete(socketId);
    const set = this.userSockets.get(presence.userId);
    if (!set) return;
    set.delete(socketId);
    if (set.size === 0) {
      this.userSockets.delete(presence.userId);
    }
  }

  setForeground(socketId: string, foreground: boolean) {
    const presence = this.sockets.get(socketId);
    if (!presence) return;
    presence.foreground = foreground;
  }

  hasSocket(userId: string) {
    return (this.userSockets.get(userId)?.size ?? 0) > 0;
  }

  /** True when at least one device is connected and in the foreground. */
  shouldUseSocket(userId: string) {
    const set = this.userSockets.get(userId);
    if (!set || set.size === 0) return false;
    for (const socketId of set) {
      if (this.sockets.get(socketId)?.foreground) return true;
    }
    return false;
  }

  userIdOf(socketId: string) {
    return this.sockets.get(socketId)?.userId ?? null;
  }
}
