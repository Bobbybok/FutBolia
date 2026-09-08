import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, IsNull, LessThan, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { toPlatformRole } from '../../common/enums';
import { FriendsService } from '../friends/friends.service';
import { Conversation } from './entities/conversation.entity';
import { DirectMessage } from './entities/direct-message.entity';
import { SendDirectMessageDto } from './dto/send-message.dto';

@Injectable()
export class ConversationsService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly friends: FriendsService,
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
        const last = await this.messages.findOne({
          where: { conversationId: row.id, deletedAt: IsNull() },
          order: { createdAt: 'DESC' },
        });
        const unreadCount = await this.messages.count({
          where: {
            conversationId: row.id,
            deletedAt: IsNull(),
            readAt: IsNull(),
            senderId: Not(userId),
          },
        });
        const friend = row.user1Id === userId ? row.user2 : row.user1;
        const canSend = await this.friends.areFriends(userId, friend.id);
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

    items.sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    );
    return items;
  }

  async unreadCount(userId: string) {
    const rows = await this.conversations.find({
      where: [{ user1Id: userId }, { user2Id: userId }],
      select: { id: true },
    });
    if (rows.length === 0) {
      return { count: 0 };
    }
    const count = await this.messages.count({
      where: rows.map((row) => ({
        conversationId: row.id,
        deletedAt: IsNull(),
        readAt: IsNull(),
        senderId: Not(userId),
      })),
    });
    return { count };
  }

  async open(userId: string, friendId: string) {
    if (userId === friendId) {
      throw new ForbiddenException('Conversation impossible avec soi-même');
    }
    await this.friends.assertFriends(userId, friendId);
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
    return this.toConversation(conversation, userId, true);
  }

  async listMessages(
    userId: string,
    conversationId: string,
    params?: { before?: string; limit?: number },
  ) {
    const conversation = await this.requireMember(conversationId, userId);
    const limit = Math.min(Math.max(params?.limit ?? 50, 1), 100);
    let beforeDate: Date | undefined;
    if (params?.before) {
      const cursor = await this.messages.findOne({
        where: { id: params.before, conversationId },
      });
      beforeDate = cursor?.createdAt;
    }
    const rows = await this.messages.find({
      where: beforeDate
        ? {
            conversationId,
            deletedAt: IsNull(),
            createdAt: LessThan(beforeDate),
          }
        : { conversationId, deletedAt: IsNull() },
      relations: { sender: { profile: true } },
      order: { createdAt: 'DESC' },
      take: limit,
    });
    const canSend = await this.friends.areFriends(
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
    await this.friends.assertFriends(
      userId,
      this.otherUserId(conversation, userId),
    );
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
    return this.toPublicMessage(full!, userId);
  }

  async deleteMessage(userId: string, conversationId: string, messageId: string) {
    await this.requireMember(conversationId, userId);
    const message = await this.messages.findOne({
      where: { id: messageId, conversationId },
    });
    if (!message || message.deletedAt) {
      throw new NotFoundException('Message introuvable');
    }
    if (message.senderId !== userId) {
      throw new ForbiddenException('Tu ne peux supprimer que tes messages');
    }
    message.deletedAt = new Date();
    await this.messages.save(message);
    return { success: true, id: messageId };
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

  private toFriend(user: Conversation['user1']) {
    return {
      id: user.id,
      pseudo: user.profile?.pseudo ?? '',
      role: toPlatformRole(user.globalRole),
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
