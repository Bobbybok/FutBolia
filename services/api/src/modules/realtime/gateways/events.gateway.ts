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
import { isStaff, TournamentMemberRole } from '../../../common/enums';
import { TYPEORM_DATA_SOURCE } from '../../../database/database.module';
import { TournamentMember } from '../../tournaments/entities/tournament-member.entity';
import { Tournament } from '../../tournaments/entities/tournament.entity';
import { TeamMember } from '../../teams/entities/team-member.entity';
import { Team } from '../../teams/entities/team.entity';
import { User } from '../../users/entities/user.entity';
import { actorCanManageTournaments } from '../../../common/staff-access';
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

  @SubscribeMessage('joinTeam')
  async joinTeam(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: string | { teamId?: string },
  ) {
    const userId = this.requireUser(client);
    const teamId = this.readId(body, 'teamId');
    if (!userId || !teamId) return { ok: false };
    const allowed = await this.canJoinTeam(userId, teamId);
    if (!allowed) return { ok: false };
    await client.join(this.dispatch.teamRoom(teamId));
    return { ok: true };
  }

  @SubscribeMessage('leaveTeam')
  async leaveTeam(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: string | { teamId?: string },
  ) {
    const teamId = this.readId(body, 'teamId');
    if (!teamId) return { ok: false };
    await client.leave(this.dispatch.teamRoom(teamId));
    return { ok: true };
  }

  @SubscribeMessage('joinInterTeam')
  async joinInterTeam(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: string | { tournamentId?: string },
  ) {
    const userId = this.requireUser(client);
    const tournamentId = this.readId(body, 'tournamentId');
    if (!userId || !tournamentId) return { ok: false };
    return { ok: false };
  }

  @SubscribeMessage('leaveInterTeam')
  async leaveInterTeam(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: string | { tournamentId?: string },
  ) {
    const tournamentId = this.readId(body, 'tournamentId');
    if (!tournamentId) return { ok: false };
    await client.leave(this.dispatch.interTeamRoom(tournamentId));
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
    body: string | { tournamentId?: string; teamId?: string } | undefined,
    key: 'tournamentId' | 'teamId',
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

  private async canJoinTeam(userId: string, teamId: string) {
    if (!this.dataSource) return false;
    const member = await this.dataSource.getRepository(TeamMember).findOne({
      where: { teamId, userId },
    });
    if (member) return true;
    const team = await this.dataSource.getRepository(Team).findOne({
      where: { id: teamId },
    });
    if (!team) return false;
    const organizer = await this.dataSource
      .getRepository(TournamentMember)
      .findOne({
        where: {
          tournamentId: team.tournamentId,
          userId,
          role: TournamentMemberRole.ORGANIZER,
        },
      });
    if (organizer) return true;
    if (team.createdById === userId) return true;
    const user = await this.dataSource.getRepository(User).findOne({
      where: { id: userId },
    });
    return isStaff(user?.globalRole);
  }

  private async canJoinInterTeam(userId: string, tournamentId: string) {
    if (!this.dataSource) return false;
    const captain = await this.dataSource.getRepository(Team).findOne({
      where: { tournamentId, captainId: userId },
    });
    if (captain) return true;
    const organizer = await this.dataSource
      .getRepository(TournamentMember)
      .findOne({
        where: {
          tournamentId,
          userId,
          role: TournamentMemberRole.ORGANIZER,
        },
      });
    if (organizer) return true;
    const tournament = await this.dataSource
      .getRepository(Tournament)
      .findOne({ where: { id: tournamentId } });
    if (tournament?.createdById === userId) return true;
    return actorCanManageTournaments(this.dataSource, userId);
  }
}
