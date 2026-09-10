import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { And, DataSource, IsNull, LessThan, MoreThan, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  isStaff,
  toPlatformRole,
  TournamentMemberRole,
} from '../../common/enums';
import { actorCanManageTournaments } from '../../common/staff-access';
import { Team } from '../teams/entities/team.entity';
import { TeamMember } from '../teams/entities/team-member.entity';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { User } from '../users/entities/user.entity';
import { TeamChatMessage } from './entities/team-chat-message.entity';
import { TeamChatReceipt } from './entities/team-chat-receipt.entity';
import { PostChatMessageDto } from './dto/post-chat-message.dto';
import { RealtimeDispatchService } from '../realtime/services/realtime-dispatch.service';
import { RealtimeEvents } from '../realtime/realtime-events';

@Injectable()
export class TeamChatService {
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

  private get messages(): Repository<TeamChatMessage> {
    return this.db.getRepository(TeamChatMessage);
  }

  private get receipts(): Repository<TeamChatReceipt> {
    return this.db.getRepository(TeamChatReceipt);
  }

  private get teams(): Repository<Team> {
    return this.db.getRepository(Team);
  }

  private get teamMembers(): Repository<TeamMember> {
    return this.db.getRepository(TeamMember);
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

  async list(
    teamId: string,
    viewerId: string,
    params?: { before?: string; limit?: number; restoreInbox?: boolean },
  ) {
    const access = await this.requireAccess(teamId, viewerId);
    const receipt = await this.getReceipt(teamId, viewerId);
    if (params?.restoreInbox && receipt.chatHiddenAt) {
      receipt.chatHiddenAt = null;
      await this.receipts.save(receipt);
    }

    const limit = Math.min(Math.max(params?.limit ?? 50, 1), 100);
    let beforeDate: Date | undefined;
    if (params?.before) {
      const cursor = await this.messages.findOne({
        where: { id: params.before, teamId },
      });
      beforeDate = cursor?.createdAt;
    }

    const clearedAt = receipt.chatClearedAt;
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
        teamId,
        deletedAt: IsNull(),
        ...(createdAt ? { createdAt } : {}),
      },
      relations: { author: { profile: true } },
      order: { createdAt: 'DESC' },
      take: limit,
    });

    receipt.lastReadAt = new Date();
    await this.receipts.save(receipt);

    return {
      teamId,
      teamName: access.team.name,
      canSend: true,
      canClearForEveryone: access.organizer || access.staff,
      messages: rows.reverse().map((m) => this.toPublic(m, viewerId)),
    };
  }

  async inbox(userId: string) {
    const memberTeams = await this.teamMembers.find({
      where: { userId },
      relations: { team: { tournament: true } },
    });
    const orgaTeams = await this.teamsForOrganizer(userId);
    const byId = new Map<string, Team>();
    for (const row of memberTeams) {
      if (row.team) byId.set(row.team.id, row.team);
    }
    for (const team of orgaTeams) {
      byId.set(team.id, team);
    }

    const items = await Promise.all(
      [...byId.values()].map(async (team) => {
        const receipt = await this.receipts.findOne({
          where: { teamId: team.id, userId },
        });
        if (receipt?.chatHiddenAt) return null;
        const last = await this.messages.findOne({
          where: {
            teamId: team.id,
            deletedAt: IsNull(),
            ...(receipt?.chatClearedAt
              ? { createdAt: MoreThan(receipt.chatClearedAt) }
              : {}),
          },
          relations: { author: { profile: true } },
          order: { createdAt: 'DESC' },
        });
        const isMember = memberTeams.some((m) => m.teamId === team.id);
        if (!isMember && !last) return null;
        const unreadCount = await this.unreadFor(team.id, userId, receipt);
        return {
          kind: 'team' as const,
          id: team.id,
          teamId: team.id,
          tournamentId: team.tournamentId,
          name: team.name,
          tournamentName: team.tournament?.name ?? null,
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
          updatedAt: last?.createdAt ?? team.createdAt,
        };
      }),
    );

    return items.filter(
      (item): item is NonNullable<(typeof items)[number]> => item != null,
    );
  }

  async unreadCount(userId: string) {
    const items = await this.inbox(userId);
    return items.reduce((sum, item) => sum + item.unreadCount, 0);
  }

  async post(teamId: string, authorId: string, dto: PostChatMessageDto) {
    const access = await this.requireAccess(teamId, authorId);
    const body = dto.body.trim();
    if (!body) {
      throw new BadRequestException('Le message ne peut pas être vide');
    }

    const saved = await this.messages.save(
      this.messages.create({
        teamId,
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
      this.realtime.teamRoom(teamId),
      RealtimeEvents.teamMessage,
      socketPayload,
    );

    const recipients = await this.recipientIds(access.team);
    const preview = `${socketPayload.authorPseudo ?? 'Quelqu’un'}: ${body}`.slice(
      0,
      140,
    );
    await Promise.all(
      recipients.map((userId) =>
        this.realtime.notifyUser({
          userId,
          event: RealtimeEvents.teamMessage,
          payload: socketPayload,
          skipPush: userId === authorId,
          push: {
            title: access.team.name,
            body: preview,
            data: {
              type: 'team_message',
              teamId,
              tournamentId: access.team.tournamentId,
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
    const access = await this.requireAccess(message.teamId, actorId);
    const isAuthor = message.authorId === actorId;
    if (!isAuthor && !access.organizer && !access.staff && !access.captain) {
      throw new ForbiddenException(
        'Seul l’auteur, le capitaine, l’orga ou un admin peut supprimer ce message',
      );
    }
    message.deletedAt = new Date();
    message.deletedById = actorId;
    await this.messages.save(message);
    const deletedPayload = { id: messageId, teamId: message.teamId };
    this.realtime.emitToRoom(
      this.realtime.teamRoom(message.teamId),
      RealtimeEvents.teamMessageDeleted,
      deletedPayload,
    );
    return { success: true, message: 'Message supprimé', id: messageId };
  }

  async clearForMe(teamId: string, userId: string) {
    await this.requireAccess(teamId, userId);
    const receipt = await this.getReceipt(teamId, userId);
    const now = new Date();
    receipt.chatClearedAt = now;
    receipt.lastReadAt = now;
    await this.receipts.save(receipt);
    return { success: true };
  }

  async hideForMe(teamId: string, userId: string) {
    await this.requireAccess(teamId, userId);
    const receipt = await this.getReceipt(teamId, userId);
    const now = new Date();
    receipt.chatHiddenAt = now;
    receipt.lastReadAt = now;
    await this.receipts.save(receipt);
    return { success: true };
  }

  async clearForEveryone(teamId: string, actorId: string) {
    const access = await this.requireAccess(teamId, actorId);
    if (!access.organizer && !access.staff && !access.captain) {
      throw new ForbiddenException(
        'Seul le capitaine ou l’organisateur peut vider le chat d’équipe',
      );
    }
    const now = new Date();
    await this.messages
      .createQueryBuilder()
      .update(TeamChatMessage)
      .set({ deletedAt: now, deletedById: actorId })
      .where('team_id = :teamId', { teamId })
      .andWhere('deleted_at IS NULL')
      .execute();
    const clearedPayload = { teamId };
    this.realtime.emitToRoom(
      this.realtime.teamRoom(teamId),
      RealtimeEvents.teamChatCleared,
      clearedPayload,
    );
    return { success: true };
  }

  private async requireAccess(teamId: string, userId: string) {
    const team = await this.teams.findOne({
      where: { id: teamId },
      relations: { tournament: true },
    });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    const member = await this.teamMembers.findOne({
      where: { teamId, userId },
    });
    const tournamentMember = await this.tournamentMembers.findOne({
      where: { tournamentId: team.tournamentId, userId },
    });
    const user = await this.users.findOne({ where: { id: userId } });
    const staff =
      isStaff(user?.globalRole) ||
      (await actorCanManageTournaments(this.db, userId));
    const organizer =
      tournamentMember?.role === TournamentMemberRole.ORGANIZER ||
      team.tournament?.createdById === userId;
    const captain = team.captainId === userId;
    if (!member && !organizer && !staff) {
      throw new ForbiddenException(
        'Seuls les membres de l’équipe (ou l’orga) peuvent accéder à ce chat',
      );
    }
    return { team, member, organizer, staff, captain };
  }

  private async getReceipt(teamId: string, userId: string) {
    const existing = await this.receipts.findOne({
      where: { teamId, userId },
    });
    if (existing) return existing;
    return this.receipts.save(
      this.receipts.create({
        teamId,
        userId,
        lastReadAt: null,
        chatClearedAt: null,
        chatHiddenAt: null,
      }),
    );
  }

  private async unreadFor(
    teamId: string,
    userId: string,
    receipt: TeamChatReceipt | null,
  ) {
    if (receipt?.chatHiddenAt) return 0;
    const qb = this.messages
      .createQueryBuilder('m')
      .where('m.team_id = :teamId', { teamId })
      .andWhere('m.deleted_at IS NULL')
      .andWhere('m.author_id != :userId', { userId });
    if (receipt?.chatClearedAt) {
      qb.andWhere('m.created_at > :clearedAt', {
        clearedAt: receipt.chatClearedAt,
      });
    }
    if (receipt?.lastReadAt) {
      qb.andWhere('m.created_at > :readAt', { readAt: receipt.lastReadAt });
    }
    return qb.getCount();
  }

  private async teamsForOrganizer(userId: string) {
    const organized = await this.tournamentMembers.find({
      where: { userId, role: TournamentMemberRole.ORGANIZER },
    });
    const created = await this.tournaments.find({
      where: { createdById: userId },
    });
    const ids = new Set([
      ...organized.map((m) => m.tournamentId),
      ...created.map((t) => t.id),
    ]);
    if (ids.size === 0) return [];
    return this.teams.find({
      where: [...ids].map((tournamentId) => ({ tournamentId })),
      relations: { tournament: true },
    });
  }

  private async recipientIds(team: Team) {
    const members = await this.teamMembers.find({
      where: { teamId: team.id },
    });
    const ids = new Set(members.map((m) => m.userId));
    const organizers = await this.tournamentMembers.find({
      where: {
        tournamentId: team.tournamentId,
        role: TournamentMemberRole.ORGANIZER,
      },
    });
    for (const row of organizers) ids.add(row.userId);
    ids.add(team.createdById);
    return [...ids];
  }

  private toPublic(message: TeamChatMessage, viewerId: string) {
    return {
      id: message.id,
      teamId: message.teamId,
      authorId: message.authorId,
      authorPseudo: message.author?.profile?.pseudo ?? null,
      authorRole: toPlatformRole(message.author?.globalRole),
      body: message.body,
      createdAt: message.createdAt,
      isMine: message.authorId === viewerId,
    };
  }

  private toSocketMessage(message: ReturnType<TeamChatService['toPublic']>) {
    const { isMine: _isMine, ...rest } = message;
    return rest;
  }
}
