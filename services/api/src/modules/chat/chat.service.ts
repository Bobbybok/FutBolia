import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, And, IsNull, LessThan, MoreThan, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { toPlatformRole, TournamentMemberRole, isStaff } from '../../common/enums';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { User } from '../users/entities/user.entity';
import { TournamentChatMessage } from './entities/tournament-chat-message.entity';
import { PostChatMessageDto } from './dto/post-chat-message.dto';
import { RealtimeDispatchService } from '../realtime/services/realtime-dispatch.service';
import { RealtimeEvents } from '../realtime/realtime-events';
import { TeamChatService } from './team-chat.service';
import { InterTeamChatService } from './inter-team-chat.service';

@Injectable()
export class ChatService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly realtime: RealtimeDispatchService,
    private readonly teamChat: TeamChatService,
    private readonly interTeamChat: InterTeamChatService,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get messages(): Repository<TournamentChatMessage> {
    return this.db.getRepository(TournamentChatMessage);
  }

  private get tournaments(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get tournamentMembers(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  private async actorIsStaff(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    return isStaff(user?.globalRole);
  }

  async list(
    tournamentId: string,
    viewerId: string,
    params?: { before?: string; limit?: number; restoreInbox?: boolean },
  ) {
    const membership = await this.tournamentMembers.findOne({
      where: { tournamentId, userId: viewerId },
    });
    if (!membership && !(await this.actorIsStaff(viewerId))) {
      throw new ForbiddenException(
        'Seuls les participants peuvent accéder au chat du tournoi',
      );
    }

    if (membership && params?.restoreInbox && membership.chatHiddenAt) {
      membership.chatHiddenAt = null;
      await this.tournamentMembers.save(membership);
    }

    const limit = Math.min(Math.max(params?.limit ?? 50, 1), 100);

    let beforeDate: Date | undefined;
    if (params?.before) {
      const cursor = await this.messages.findOne({
        where: { id: params.before, tournamentId },
      });
      beforeDate = cursor?.createdAt;
    }

    const clearedAt = membership?.chatClearedAt ?? null;
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
        tournamentId,
        deletedAt: IsNull(),
        ...(createdAt ? { createdAt } : {}),
      },
      relations: { author: { profile: true } },
      order: { createdAt: 'DESC' },
      take: limit,
    });

    if (membership) {
      membership.lastReadAt = new Date();
      await this.tournamentMembers.save(membership);
    }

    return rows.reverse().map((m) => this.toPublic(m, viewerId));
  }

  async inbox(userId: string) {
    const memberships = await this.tournamentMembers.find({
      where: { userId },
      relations: { tournament: true },
    });

    const items = await Promise.all(
      memberships
        .filter((mem) => mem.tournament)
        .map(async (mem) => {
          if (mem.chatHiddenAt) return null;
          const last = await this.messages.findOne({
            where: {
              tournamentId: mem.tournamentId,
              deletedAt: IsNull(),
              ...(mem.chatClearedAt
                ? { createdAt: MoreThan(mem.chatClearedAt) }
                : {}),
            },
            relations: { author: { profile: true } },
            order: { createdAt: 'DESC' },
          });
          const unreadCount = await this.unreadForMembership(mem, userId);
          const isOrganizer =
            mem.role === TournamentMemberRole.ORGANIZER ||
            mem.tournament.createdById === userId;
          return {
            kind: 'tournament' as const,
            id: mem.tournamentId,
            tournamentId: mem.tournamentId,
            name: mem.tournament.name,
            visibility: mem.tournament.visibility,
            isOrganizer,
            lastMessage: last
              ? {
                  id: last.id,
                  body: last.body,
                  senderId: last.authorId,
                  authorPseudo: last.author?.profile?.pseudo ?? null,
                  createdAt: last.createdAt,
                }
              : null,
            unreadCount,
            updatedAt: last?.createdAt ?? mem.joinedAt,
          };
        }),
    );

    const visible = items.filter(
      (item): item is NonNullable<(typeof items)[number]> => item != null,
    );

    visible.sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    );
    const teams = await this.teamChat.inbox(userId);
    const interTeams = await this.interTeamChat.inbox(userId);
    const merged = [...visible, ...teams, ...interTeams];
    merged.sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    );
    return merged;
  }

  async unreadCount(userId: string) {
    const count = await this.messages
      .createQueryBuilder('m')
      .innerJoin(
        'tournament_members',
        'mem',
        'mem.tournament_id = m.tournament_id AND mem.user_id = :userId',
        { userId },
      )
      .where('m.deleted_at IS NULL')
      .andWhere('m.author_id != :userId', { userId })
      .andWhere(
        '(mem.last_read_at IS NULL OR m.created_at > mem.last_read_at)',
      )
      .andWhere(
        '(mem.chat_cleared_at IS NULL OR m.created_at > mem.chat_cleared_at)',
      )
      .andWhere('mem.chat_hidden_at IS NULL')
      .getCount();
    const teams = await this.teamChat.unreadCount(userId);
    const interTeams = await this.interTeamChat.unreadCount(userId);
    return { count: count + teams + interTeams };
  }

  private async unreadForMembership(
    membership: TournamentMember,
    userId: string,
  ) {
    if (membership.chatHiddenAt) return 0;
    const qb = this.messages
      .createQueryBuilder('m')
      .where('m.tournament_id = :tournamentId', {
        tournamentId: membership.tournamentId,
      })
      .andWhere('m.deleted_at IS NULL')
      .andWhere('m.author_id != :userId', { userId });
    if (membership.chatClearedAt) {
      qb.andWhere('m.created_at > :clearedAt', {
        clearedAt: membership.chatClearedAt,
      });
    }
    if (membership.lastReadAt) {
      qb.andWhere('m.created_at > :readAt', {
        readAt: membership.lastReadAt,
      });
    }
    return qb.getCount();
  }

  async post(
    tournamentId: string,
    authorId: string,
    dto: PostChatMessageDto,
  ) {
    await this.requireParticipant(tournamentId, authorId);
    const tournament = await this.requireTournament(tournamentId);

    const body = dto.body.trim();
    if (!body) {
      throw new BadRequestException('Le message ne peut pas être vide');
    }

    const saved = await this.messages.save(
      this.messages.create({
        tournamentId,
        authorId,
        body,
        deletedAt: null,
        deletedById: null,
      }),
    );

    const full = await this.messages.findOne({
      where: { id: saved.id },
      relations: { author: { profile: true } },
    });
    const published = this.toPublic(full!, authorId);
    const socketPayload = this.toSocketMessage(published);
    this.realtime.emitToRoom(
      this.realtime.tournamentRoom(tournamentId),
      RealtimeEvents.tournamentMessage,
      socketPayload,
    );
    const members = await this.tournamentMembers.find({
      where: { tournamentId },
    });
    const preview = `${socketPayload.authorPseudo ?? 'Quelqu’un'}: ${body}`.slice(
      0,
      140,
    );
    await Promise.all(
      members.map((mem) =>
        this.realtime.notifyUser({
          userId: mem.userId,
          event: RealtimeEvents.tournamentMessage,
          payload: socketPayload,
          skipPush: mem.userId === authorId,
          push: {
            title: tournament.name,
            body: preview,
            data: {
              type: 'tournament_message',
              tournamentId,
              messageId: saved.id,
            },
          },
        }),
      ),
    );
    return published;
  }

  async remove(messageId: string, actorId: string) {
    const message = await this.messages.findOne({ where: { id: messageId } });
    if (!message || message.deletedAt) {
      throw new NotFoundException('Message introuvable');
    }

    const staff = await this.actorIsStaff(actorId);
    const membership = await this.tournamentMembers.findOne({
      where: { tournamentId: message.tournamentId, userId: actorId },
    });
    if (!membership && !staff) {
      throw new ForbiddenException(
        'Seuls les participants peuvent accéder au chat du tournoi',
      );
    }
    const tournament = await this.requireTournament(message.tournamentId);
    const isOrganizer =
      membership?.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === actorId;
    const isAuthor = message.authorId === actorId;

    if (!isAuthor && !isOrganizer && !staff) {
      throw new ForbiddenException(
        'Seul l’auteur, l’organisateur, un modo ou un admin peut supprimer ce message',
      );
    }

    message.deletedAt = new Date();
    message.deletedById = actorId;
    await this.messages.save(message);

    const deletedPayload = {
      id: messageId,
      tournamentId: message.tournamentId,
    };
    this.realtime.emitToRoom(
      this.realtime.tournamentRoom(message.tournamentId),
      RealtimeEvents.tournamentMessageDeleted,
      deletedPayload,
    );
    const members = await this.tournamentMembers.find({
      where: { tournamentId: message.tournamentId },
    });
    await Promise.all(
      members.map((mem) =>
        this.realtime.notifyUser({
          userId: mem.userId,
          event: RealtimeEvents.tournamentMessageDeleted,
          payload: deletedPayload,
          skipPush: true,
        }),
      ),
    );

    return { success: true, message: 'Message supprimé', id: messageId };
  }

  async clearForMe(tournamentId: string, userId: string) {
    const membership = await this.requireParticipant(tournamentId, userId);
    const now = new Date();
    membership.chatClearedAt = now;
    membership.lastReadAt = now;
    await this.tournamentMembers.save(membership);
    return { success: true };
  }

  async hideForMe(tournamentId: string, userId: string) {
    const membership = await this.requireParticipant(tournamentId, userId);
    const now = new Date();
    membership.chatHiddenAt = now;
    membership.lastReadAt = now;
    await this.tournamentMembers.save(membership);
    return { success: true };
  }

  async clearForEveryone(tournamentId: string, actorId: string) {
    const membership = await this.requireParticipant(tournamentId, actorId);
    const tournament = await this.requireTournament(tournamentId);
    const isOrganizer =
      membership.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === actorId;
    if (!isOrganizer) {
      throw new ForbiddenException(
        'Seul l’organisateur peut vider le chat pour tout le monde',
      );
    }
    const now = new Date();
    await this.messages
      .createQueryBuilder()
      .update(TournamentChatMessage)
      .set({ deletedAt: now, deletedById: actorId })
      .where('tournament_id = :tournamentId', { tournamentId })
      .andWhere('deleted_at IS NULL')
      .execute();
    membership.chatClearedAt = now;
    membership.lastReadAt = now;
    await this.tournamentMembers.save(membership);
    const clearedPayload = { tournamentId };
    this.realtime.emitToRoom(
      this.realtime.tournamentRoom(tournamentId),
      RealtimeEvents.tournamentChatCleared,
      clearedPayload,
    );
    const members = await this.tournamentMembers.find({ where: { tournamentId } });
    await Promise.all(
      members.map((mem) =>
        this.realtime.notifyUser({
          userId: mem.userId,
          event: RealtimeEvents.tournamentChatCleared,
          payload: clearedPayload,
          skipPush: true,
        }),
      ),
    );
    return { success: true };
  }

  private async requireTournament(tournamentId: string) {
    const tournament = await this.tournaments.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    return tournament;
  }

  private async requireParticipant(tournamentId: string, userId: string) {
    const membership = await this.tournamentMembers.findOne({
      where: { tournamentId, userId },
    });
    if (!membership) {
      throw new ForbiddenException(
        'Seuls les participants peuvent accéder au chat du tournoi',
      );
    }
    return membership;
  }

  private toPublic(message: TournamentChatMessage, viewerId: string) {
    return {
      id: message.id,
      tournamentId: message.tournamentId,
      authorId: message.authorId,
      authorPseudo: message.author?.profile?.pseudo ?? null,
      authorRole: toPlatformRole(message.author?.globalRole),
      body: message.body,
      createdAt: message.createdAt,
      isMine: message.authorId === viewerId,
    };
  }

  private toSocketMessage(
    message: ReturnType<ChatService['toPublic']>,
  ) {
    const { isMine: _isMine, ...rest } = message;
    return rest;
  }
}
