import { Inject, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { SkipThrottle } from '@nestjs/throttler';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { DataSource } from 'typeorm';
import { authUserFromAccessPayload } from '../../../common/auth-user-from-payload';
import { isStaff } from '../../../common/enums';
import { TYPEORM_DATA_SOURCE } from '../../../database/database.module';
import { TournamentMember } from '../../tournaments/entities/tournament-member.entity';
import { User } from '../../users/entities/user.entity';
import { ConnectionRegistryService } from '../services/connection-registry.service';
import { RealtimeDispatchService } from '../services/realtime-dispatch.service';

type AccessPayload = {
  sub: string;
  email: string;
  globalRole?: string;
  role?: string;
  permissions?: string[];
};

@SkipThrottle()
@WebSocketGateway({
  cors: { origin: true, credentials: true },
  transports: ['websocket', 'polling'],
  pingInterval: 25_000,
  pingTimeout: 20_000,
  allowEIO3: true,
})
export class EventsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(EventsGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly registry: ConnectionRegistryService,
    private readonly dispatch: RealtimeDispatchService,
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  afterInit(server: Server) {
    this.dispatch.attach(server);
  }

  async handleConnection(client: Socket) {
    const token = this.readToken(client);
    if (!token) {
      client.disconnect(true);
      return;
    }
    try {
      const payload = this.jwt.verify<AccessPayload>(token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
      const user = authUserFromAccessPayload(payload);
      client.data.userId = user.id;
      this.registry.add(user.id, client.id);
      await client.join(this.dispatch.userRoom(user.id));
      this.logger.log(`Socket connecté user=${user.id}`);
    } catch {
      this.logger.warn(`Socket ${client.id} rejeté (JWT invalide ou expiré)`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    this.registry.remove(client.id);
  }

  @SubscribeMessage('joinTournament')
  async joinTournament(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: string | { tournamentId?: string },
  ) {
    const userId = this.requireUser(client);
    const tournamentId = this.readId(body, 'tournamentId');
    if (!userId || !tournamentId) {
      return { ok: false };
    }
    const allowed = await this.canJoinTournament(userId, tournamentId);
    if (!allowed) {
      return { ok: false };
    }
    await client.join(this.dispatch.tournamentRoom(tournamentId));
    return { ok: true };
  }

  @SubscribeMessage('leaveTournament')
  async leaveTournament(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: string | { tournamentId?: string },
  ) {
    const tournamentId = this.readId(body, 'tournamentId');
    if (!tournamentId) return { ok: false };
    await client.leave(this.dispatch.tournamentRoom(tournamentId));
    return { ok: true };
  }

  @SubscribeMessage('app:foreground')
  handleForeground(@ConnectedSocket() client: Socket) {
    this.registry.setForeground(client.id, true);
    return { ok: true };
  }

  @SubscribeMessage('app:background')
  handleBackground(@ConnectedSocket() client: Socket) {
    this.registry.setForeground(client.id, false);
    return { ok: true };
  }

  private readToken(client: Socket) {
    const auth = client.handshake.auth as { token?: unknown } | undefined;
    if (typeof auth?.token === 'string' && auth.token.trim()) {
      return auth.token.trim();
    }
    const query = client.handshake.query?.token;
    if (typeof query === 'string' && query.trim()) {
      return query.trim();
    }
    if (Array.isArray(query) && typeof query[0] === 'string') {
      return query[0].trim();
    }
    const header = client.handshake.headers.authorization;
    if (typeof header === 'string' && header.startsWith('Bearer ')) {
      return header.slice('Bearer '.length).trim();
    }
    return null;
  }

  private requireUser(client: Socket) {
    return typeof client.data.userId === 'string' ? client.data.userId : null;
  }

  private readId(
    body: string | { tournamentId?: string } | undefined,
    key: 'tournamentId',
  ) {
    if (typeof body === 'string' && body.trim()) return body.trim();
    if (body && typeof body === 'object' && typeof body[key] === 'string') {
      return body[key]!.trim();
    }
    return null;
  }

  private async canJoinTournament(userId: string, tournamentId: string) {
    if (!this.dataSource) return false;
    const member = await this.dataSource.getRepository(TournamentMember).findOne({
      where: { tournamentId, userId },
    });
    if (member) return true;
    const user = await this.dataSource.getRepository(User).findOne({
      where: { id: userId },
    });
    return isStaff(user?.globalRole);
  }
}
