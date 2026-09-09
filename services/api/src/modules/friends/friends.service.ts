import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, ILike, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { FriendRequestStatus, toPlatformRole } from '../../common/enums';
import { FriendRequest } from './entities/friend-request.entity';
import { User } from '../users/entities/user.entity';
import { Profile } from '../users/entities/profile.entity';
import { SendFriendRequestDto } from './dto/friends.dto';
import { RealtimeDispatchService } from '../realtime/services/realtime-dispatch.service';
import { RealtimeEvents } from '../realtime/realtime-events';

@Injectable()
export class FriendsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly realtime: RealtimeDispatchService,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get requests(): Repository<FriendRequest> {
    return this.db.getRepository(FriendRequest);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  private get profiles(): Repository<Profile> {
    return this.db.getRepository(Profile);
  }

  async listFriends(userId: string) {
    const rows = await this.requests.find({
      where: [
        { fromUserId: userId, status: FriendRequestStatus.ACCEPTED },
        { toUserId: userId, status: FriendRequestStatus.ACCEPTED },
      ],
      relations: { fromUser: { profile: true }, toUser: { profile: true } },
      order: { updatedAt: 'DESC' },
    });
    return rows
      .map((row) => {
        const other = row.fromUserId === userId ? row.toUser : row.fromUser;
        return other ? this.toPublicUser(other) : null;
      })
      .filter((item): item is NonNullable<typeof item> => item != null);
  }

  async listRequests(userId: string) {
    const [incoming, outgoing] = await Promise.all([
      this.requests.find({
        where: { toUserId: userId, status: FriendRequestStatus.PENDING },
        relations: { fromUser: { profile: true } },
        order: { createdAt: 'DESC' },
      }),
      this.requests.find({
        where: { fromUserId: userId, status: FriendRequestStatus.PENDING },
        relations: { toUser: { profile: true } },
        order: { createdAt: 'DESC' },
      }),
    ]);
    return {
      incoming: incoming
        .filter((row) => row.fromUser)
        .map((row) => ({
          id: row.id,
          createdAt: row.createdAt,
          user: this.toPublicUser(row.fromUser),
        })),
      outgoing: outgoing
        .filter((row) => row.toUser)
        .map((row) => ({
          id: row.id,
          createdAt: row.createdAt,
          user: this.toPublicUser(row.toUser),
        })),
    };
  }

  async search(userId: string, query?: string) {
    const q = query?.trim();
    if (!q || q.length < 2) {
      throw new BadRequestException('Tape au moins 2 caractères');
    }
    const profiles = await this.profiles.find({
      where: { pseudo: ILike(`%${q}%`) },
      relations: { user: true },
      take: 20,
    });
    const hits = profiles.filter(
      (p) => p.user && p.userId !== userId && !p.user.deletedAt,
    );
    const statuses = await this.statusMap(
      userId,
      hits.map((p) => p.userId),
    );
    return hits.map((p) => ({
      id: p.user.id,
      pseudo: p.pseudo,
      role: toPlatformRole(p.user.globalRole),
      city: p.city ?? null,
      friendship: statuses.get(p.userId) ?? 'none',
    }));
  }

  async sendRequest(actorId: string, dto: SendFriendRequestDto) {
    const target = await this.resolveTarget(actorId, dto);
    const existing = await this.findPair(actorId, target.id);

    if (existing?.status === FriendRequestStatus.ACCEPTED) {
      throw new ConflictException('Vous êtes déjà amis');
    }

    if (existing?.status === FriendRequestStatus.PENDING) {
      if (existing.fromUserId === actorId) {
        throw new ConflictException('Demande déjà envoyée');
      }
      existing.status = FriendRequestStatus.ACCEPTED;
      existing.respondedAt = new Date();
      await this.requests.save(existing);
      await this.notifyFriendAccepted(actorId, existing.fromUserId);
      return { success: true, status: 'accepted' };
    }

    if (existing) {
      existing.fromUserId = actorId;
      existing.toUserId = target.id;
      existing.status = FriendRequestStatus.PENDING;
      existing.respondedAt = null;
      await this.requests.save(existing);
      await this.notifyFriendRequest(actorId, target.id, existing.id);
      return { success: true, status: 'pending', id: existing.id };
    }

    const saved = await this.requests.save(
      this.requests.create({
        fromUserId: actorId,
        toUserId: target.id,
        status: FriendRequestStatus.PENDING,
      }),
    );
    await this.notifyFriendRequest(actorId, target.id, saved.id);
    return { success: true, status: 'pending', id: saved.id };
  }

  async accept(actorId: string, requestId: string) {
    const row = await this.requireRequest(requestId);
    if (row.toUserId !== actorId) {
      throw new ForbiddenException("Cette demande ne t'est pas destinée");
    }
    if (row.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('Cette demande n’est plus en attente');
    }
    row.status = FriendRequestStatus.ACCEPTED;
    row.respondedAt = new Date();
    await this.requests.save(row);
    await this.notifyFriendAccepted(actorId, row.fromUserId);
    return { success: true };
  }

  async decline(actorId: string, requestId: string) {
    const row = await this.requireRequest(requestId);
    if (row.toUserId !== actorId) {
      throw new ForbiddenException("Cette demande ne t'est pas destinée");
    }
    if (row.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('Cette demande n’est plus en attente');
    }
    row.status = FriendRequestStatus.DECLINED;
    row.respondedAt = new Date();
    await this.requests.save(row);
    return { success: true };
  }

  async unfriend(actorId: string, friendId: string) {
    if (actorId === friendId) {
      throw new BadRequestException('Action impossible');
    }
    const row = await this.findPair(actorId, friendId);
    if (!row || row.status !== FriendRequestStatus.ACCEPTED) {
      throw new NotFoundException('Amitié introuvable');
    }
    await this.requests.remove(row);
    return { success: true };
  }

  async areFriends(userA: string, userB: string) {
    if (userA === userB) return false;
    const row = await this.findPair(userA, userB);
    return row?.status === FriendRequestStatus.ACCEPTED;
  }

  async assertFriends(userA: string, userB: string) {
    const ok = await this.areFriends(userA, userB);
    if (!ok) {
      throw new ForbiddenException(
        'Le chat privé est réservé aux joueurs amis',
      );
    }
  }

  private async resolveTarget(actorId: string, dto: SendFriendRequestDto) {
    if (!dto.userId && !dto.pseudo?.trim()) {
      throw new BadRequestException('Indique un joueur (id ou pseudo)');
    }
    let user: User | null = null;
    if (dto.userId) {
      user = await this.users.findOne({
        where: { id: dto.userId },
        relations: { profile: true },
      });
    } else if (dto.pseudo) {
      const profile = await this.profiles.findOne({
        where: { pseudo: dto.pseudo.trim() },
        relations: { user: true },
      });
      user = profile?.user ?? null;
    }
    if (!user) {
      throw new NotFoundException('Joueur introuvable');
    }
    if (user.id === actorId) {
      throw new BadRequestException('Tu ne peux pas t’ajouter toi-même');
    }
    return user;
  }

  private async findPair(userA: string, userB: string) {
    return this.requests.findOne({
      where: [
        { fromUserId: userA, toUserId: userB },
        { fromUserId: userB, toUserId: userA },
      ],
    });
  }

  private async requireRequest(id: string) {
    const row = await this.requests.findOne({ where: { id } });
    if (!row) {
      throw new NotFoundException('Demande introuvable');
    }
    return row;
  }

  private async statusMap(actorId: string, userIds: string[]) {
    const map = new Map<string, string>();
    if (userIds.length === 0) return map;
    const rows = await this.requests.find({
      where: userIds.flatMap((id) => [
        { fromUserId: actorId, toUserId: id },
        { fromUserId: id, toUserId: actorId },
      ]),
    });
    for (const row of rows) {
      const other =
        row.fromUserId === actorId ? row.toUserId : row.fromUserId;
      if (row.status === FriendRequestStatus.ACCEPTED) {
        map.set(other, 'friends');
      } else if (row.status === FriendRequestStatus.PENDING) {
        map.set(
          other,
          row.fromUserId === actorId ? 'pending_sent' : 'pending_received',
        );
      }
    }
    return map;
  }

  private toPublicUser(user: User) {
    return {
      id: user.id,
      pseudo: user.profile?.pseudo ?? '',
      role: toPlatformRole(user.globalRole),
      city: user.profile?.city ?? null,
    };
  }

  private async loadPublicUser(userId: string) {
    const user = await this.users.findOne({
      where: { id: userId },
      relations: { profile: true },
    });
    return user ? this.toPublicUser(user) : { id: userId, pseudo: '', role: 'user', city: null };
  }

  private async notifyFriendRequest(
    fromUserId: string,
    toUserId: string,
    requestId: string,
  ) {
    const from = await this.loadPublicUser(fromUserId);
    await this.realtime.notifyUser({
      userId: toUserId,
      event: RealtimeEvents.friendRequest,
      payload: { id: requestId, user: from },
      push: {
        title: 'Demande d’ami',
        body: `${from.pseudo || 'Un joueur'} veut t’ajouter`,
        data: {
          type: 'friend_request',
          requestId,
          userId: fromUserId,
        },
      },
    });
  }

  private async notifyFriendAccepted(actorId: string, requesterId: string) {
    const actor = await this.loadPublicUser(actorId);
    await this.realtime.notifyUser({
      userId: requesterId,
      event: RealtimeEvents.friendAccepted,
      payload: { user: actor },
      push: {
        title: 'Demande acceptée',
        body: `${actor.pseudo || 'Un joueur'} a accepté ta demande`,
        data: {
          type: 'friend_accepted',
          userId: actorId,
        },
      },
    });
  }
}
