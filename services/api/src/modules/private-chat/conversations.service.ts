import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, And, IsNull, LessThan, MoreThan, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { isStaff, toPlatformRole } from '../../common/enums';
import { FriendsService } from '../friends/friends.service';
import { User } from '../users/entities/user.entity';
import { Conversation } from './entities/conversation.entity';
import { DirectMessage } from './entities/direct-message.entity';
import { SendDirectMessageDto } from './dto/send-message.dto';
import { RealtimeDispatchService } from '../realtime/services/realtime-dispatch.service';
import { RealtimeEvents } from '../realtime/realtime-events';

@Injectable()
export class ConversationsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly friends: FriendsService,
    private readonly realtime: RealtimeDispatchService,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get conversations(): Repository<Conversation> {
    return this.db.getRepository(Conversation);
  }

  private get messages(): Repository<DirectMessage> {
    return this.db.getRepository(DirectMessage);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  private async actorIsStaff(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    return isStaff(user?.globalRole);
  }

  private async canMessage(userId: string, otherId: string) {
    if (await this.actorIsStaff(userId)) return true;
    if (await this.actorIsStaff(otherId)) return true;
    return this.friends.areFriends(userId, otherId);
  }

  async list(userId: string) {
    const rows = await this.conversations.find({
      where: [{ user1Id: userId }, { user2Id: userId }],
      relations: {
        user1: { profile: true },
        user2: { profile: true },
      },
    });

    const items = await Promise.all(
      rows.map(async (row) => {
        const clearedAt = this.clearedAt(row, userId);
        const hiddenAt = this.hiddenAt(row, userId);
        const last = await this.messages.findOne({
          where: {
            conversationId: row.id,
            deletedAt: IsNull(),
            ...(clearedAt ? { createdAt: MoreThan(clearedAt) } : {}),
          },
          order: { createdAt: 'DESC' },
        });
        if (
          hiddenAt &&
          (!last || last.createdAt.getTime() <= hiddenAt.getTime())
        ) {
          return null;
        }
        const unreadWhere = {
          conversationId: row.id,
          deletedAt: IsNull(),
          readAt: IsNull(),
          senderId: Not(userId),
          ...(clearedAt ? { createdAt: MoreThan(clearedAt) } : {}),
        };
        const unreadCount = await this.messages.count({
          where: unreadWhere,
        });
        const friend = row.user1Id === userId ? row.user2 : row.user1;
        if (!friend) {
          return null;
        }
        const canSend = await this.canMessage(userId, friend.id);
        return {
          id: row.id,
          friend: this.toFriend(friend),
          lastMessage: last
            ? {
                id: last.id,
                body: last.content,
                senderId: last.senderId,
                createdAt: last.createdAt,
              }
            : null,
          unreadCount,
          canSend,
          updatedAt: last?.createdAt ?? row.createdAt,
        };
      }),
    );

    const present = items.filter(
      (item): item is NonNullable<typeof item> => item != null,
    );
    present.sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    );
    return present;
  }

  async unreadCount(userId: string) {
    const count = await this.messages
      .createQueryBuilder('m')
      .innerJoin('conversations', 'c', 'c.id = m.conversation_id')
      .where('m.deleted_at IS NULL')
      .andWhere('m.read_at IS NULL')
      .andWhere('m.sender_id != :userId', { userId })
      .andWhere('(c.user1_id = :userId OR c.user2_id = :userId)', { userId })
      .andWhere(
        `(
          (c.user1_id = :userId AND (c.user1_cleared_at IS NULL OR m.created_at > c.user1_cleared_at)
            AND (c.user1_hidden_at IS NULL OR m.created_at > c.user1_hidden_at))
          OR
          (c.user2_id = :userId AND (c.user2_cleared_at IS NULL OR m.created_at > c.user2_cleared_at)
            AND (c.user2_hidden_at IS NULL OR m.created_at > c.user2_hidden_at))
        )`,
      )
      .getCount();
    return { count };
  }

  async open(userId: string, friendId: string) {
    if (userId === friendId) {
      throw new ForbiddenException('Conversation impossible avec soi-même');
    }
    const staff = await this.actorIsStaff(userId);
    const otherIsStaff = await this.actorIsStaff(friendId);
    if (!staff && !otherIsStaff) {
      await this.friends.assertFriends(userId, friendId);
    }
    const [user1Id, user2Id] = this.orderedPair(userId, friendId);
    let conversation = await this.conversations.findOne({
      where: { user1Id, user2Id },
      relations: {
        user1: { profile: true },
        user2: { profile: true },
      },
    });
    if (!conversation) {
      conversation = await this.conversations.save(
        this.conversations.create({ user1Id, user2Id }),
      );
      conversation = await this.conversations.findOneOrFail({
        where: { id: conversation.id },
        relations: {
          user1: { profile: true },
          user2: { profile: true },
        },
      });
    }
    this.setHiddenAt(conversation, userId, null);
    await this.conversations.save(conversation);
    return this.toConversation(conversation, userId, true);
  }

  async listMessages(
    userId: string,
    conversationId: string,
    params?: { before?: string; limit?: number },
  ) {
    const conversation = await this.requireMember(conversationId, userId);
    const clearedAt = this.clearedAt(conversation, userId);
    const limit = Math.min(Math.max(params?.limit ?? 50, 1), 100);
    let beforeDate: Date | undefined;
    if (params?.before) {
      const cursor = await this.messages.findOne({
        where: { id: params.before, conversationId },
      });
      beforeDate = cursor?.createdAt;
    }
    const createdAt =
      beforeDate && clearedAt
        ? And(MoreThan(clearedAt), LessThan(beforeDate))
        : beforeDate
          ? LessThan(beforeDate)
          : clearedAt
            ? MoreThan(clearedAt)
            : undefined;
    const rows = await this.messages.find({
      where: {
        conversationId,
        deletedAt: IsNull(),
        ...(createdAt ? { createdAt } : {}),
      },
      relations: { sender: { profile: true } },
      order: { createdAt: 'DESC' },
      take: limit,
    });
    const canSend = await this.canMessage(
      userId,
      this.otherUserId(conversation, userId),
    );
    return {
      canSend,
      messages: rows.reverse().map((m) => this.toPublicMessage(m, userId)),
    };
  }

  async postMessage(
    userId: string,
    conversationId: string,
    dto: SendDirectMessageDto,
  ) {
    const conversation = await this.requireMember(conversationId, userId);
    const otherId = this.otherUserId(conversation, userId);
    if (!(await this.canMessage(userId, otherId))) {
      await this.friends.assertFriends(userId, otherId);
    }
    const saved = await this.messages.save(
      this.messages.create({
        conversationId,
        senderId: userId,
        content: dto.body.trim(),
        readAt: null,
        deletedAt: null,
      }),
    );
    const full = await this.messages.findOne({
      where: { id: saved.id },
      relations: { sender: { profile: true } },
    });
    const published = this.toPublicMessage(full!, userId);
    const socketPayload = this.toSocketMessage(published);
    const preview = `${socketPayload.authorPseudo ?? 'Quelqu’un'}: ${dto.body.trim()}`.slice(
      0,
      140,
    );
    await Promise.all([
      this.realtime.notifyUser({
        userId: otherId,
        event: RealtimeEvents.privateMessage,
        payload: socketPayload,
        push: {
          title: socketPayload.authorPseudo || 'Message privé',
          body: preview,
          data: {
            type: 'private_message',
            conversationId,
            messageId: saved.id,
            senderId: userId,
          },
        },
      }),
      this.realtime.notifyUser({
        userId,
        event: RealtimeEvents.privateMessage,
        payload: socketPayload,
        skipPush: true,
      }),
    ]);
    return published;
  }

  async deleteMessage(userId: string, conversationId: string, messageId: string) {
    const conversation = await this.requireMember(conversationId, userId);
    const message = await this.messages.findOne({
      where: { id: messageId, conversationId },
    });
    if (!message || message.deletedAt) {
      throw new NotFoundException('Message introuvable');
    }
    if (message.senderId !== userId && !(await this.actorIsStaff(userId))) {
      throw new ForbiddenException(
        'Seul l’auteur, un modo ou un admin peut supprimer ce message',
      );
    }
    message.deletedAt = new Date();
    await this.messages.save(message);
    const deletedPayload = { id: messageId, conversationId };
    const otherId = this.otherUserId(conversation, userId);
    await Promise.all(
      [userId, otherId].map((id) =>
        this.realtime.notifyUser({
          userId: id,
          event: RealtimeEvents.privateMessageDeleted,
          payload: deletedPayload,
          skipPush: true,
        }),
      ),
    );
    return { success: true, id: messageId };
  }

  async clearForMe(userId: string, conversationId: string) {
    const conversation = await this.requireMember(conversationId, userId);
    this.setClearedAt(conversation, userId, new Date());
    await this.conversations.save(conversation);
    return { success: true };
  }

  async hideForMe(userId: string, conversationId: string) {
    const conversation = await this.requireMember(conversationId, userId);
    const now = new Date();
    this.setClearedAt(conversation, userId, now);
    this.setHiddenAt(conversation, userId, now);
    await this.conversations.save(conversation);
    return { success: true };
  }

  async markRead(userId: string, conversationId: string) {
    await this.requireMember(conversationId, userId);
    await this.messages
      .createQueryBuilder()
      .update(DirectMessage)
      .set({ readAt: new Date() })
      .where('conversation_id = :conversationId', { conversationId })
      .andWhere('sender_id != :userId', { userId })
      .andWhere('read_at IS NULL')
      .andWhere('deleted_at IS NULL')
      .execute();
    return { success: true };
  }

  private async requireMember(conversationId: string, userId: string) {
    const conversation = await this.conversations.findOne({
      where: { id: conversationId },
      relations: {
        user1: { profile: true },
        user2: { profile: true },
      },
    });
    if (!conversation) {
      throw new NotFoundException('Conversation introuvable');
    }
    if (conversation.user1Id !== userId && conversation.user2Id !== userId) {
      throw new ForbiddenException("Cette conversation n'est pas à toi");
    }
    return conversation;
  }

  private clearedAt(conversation: Conversation, userId: string) {
    return conversation.user1Id === userId
      ? conversation.user1ClearedAt
      : conversation.user2ClearedAt;
  }

  private hiddenAt(conversation: Conversation, userId: string) {
    return conversation.user1Id === userId
      ? conversation.user1HiddenAt
      : conversation.user2HiddenAt;
  }

  private setClearedAt(
    conversation: Conversation,
    userId: string,
    value: Date | null,
  ) {
    if (conversation.user1Id === userId) {
      conversation.user1ClearedAt = value;
    } else {
      conversation.user2ClearedAt = value;
    }
  }

  private setHiddenAt(
    conversation: Conversation,
    userId: string,
    value: Date | null,
  ) {
    if (conversation.user1Id === userId) {
      conversation.user1HiddenAt = value;
    } else {
      conversation.user2HiddenAt = value;
    }
  }

  private toConversation(
    conversation: Conversation,
    userId: string,
    canSend: boolean,
  ) {
    const friend =
      conversation.user1Id === userId ? conversation.user2 : conversation.user1;
    return {
      id: conversation.id,
      friend: this.toFriend(friend),
      canSend,
    };
  }

  private toPublicMessage(message: DirectMessage, viewerId: string) {
    return {
      id: message.id,
      conversationId: message.conversationId,
      authorId: message.senderId,
      authorPseudo: message.sender?.profile?.pseudo ?? null,
      authorRole: toPlatformRole(message.sender?.globalRole),
      body: message.content,
      createdAt: message.createdAt,
      isMine: message.senderId === viewerId,
    };
  }

  private toSocketMessage(
    message: ReturnType<ConversationsService['toPublicMessage']>,
  ) {
    const { isMine: _isMine, ...rest } = message;
    return rest;
  }

  private toFriend(user: Conversation['user1'] | undefined) {
    return {
      id: user?.id ?? '',
      pseudo: user?.profile?.pseudo ?? '',
      role: toPlatformRole(user?.globalRole),
    };
  }

  private otherUserId(conversation: Conversation, userId: string) {
    return conversation.user1Id === userId
      ? conversation.user2Id
      : conversation.user1Id;
  }

  private orderedPair(a: string, b: string): [string, string] {
    return a < b ? [a, b] : [b, a];
  }
}
