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
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { User } from '../users/entities/user.entity';
import { InterTeamChatMessage } from './entities/inter-team-chat-message.entity';
import { InterTeamChatReceipt } from './entities/inter-team-chat-receipt.entity';
import { PostChatMessageDto } from './dto/post-chat-message.dto';
import { RealtimeDispatchService } from '../realtime/services/realtime-dispatch.service';
import { RealtimeEvents } from '../realtime/realtime-events';

@Injectable()
export class InterTeamChatService {
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

  private get messages(): Repository<InterTeamChatMessage> {
    return this.db.getRepository(InterTeamChatMessage);
  }

  private get receipts(): Repository<InterTeamChatReceipt> {
    return this.db.getRepository(InterTeamChatReceipt);
  }

  private get teams(): Repository<Team> {
    return this.db.getRepository(Team);
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

  private assertEnabled() {
    throw new ForbiddenException('Chat inter-équipes désactivé');
  }

  async list(
    tournamentId: string,
    viewerId: string,
    params?: { before?: string; limit?: number; restoreInbox?: boolean },
  ) {
    this.assertEnabled();
    const access = await this.requireAccess(tournamentId, viewerId);
    const receipt = await this.getReceipt(tournamentId, viewerId);
    if (params?.restoreInbox && receipt.chatHiddenAt) {
      receipt.chatHiddenAt = null;
      await this.receipts.save(receipt);
    }

    const limit = Math.min(Math.max(params?.limit ?? 50, 1), 100);
    let beforeDate: Date | undefined;
    if (params?.before) {
      const cursor = await this.messages.findOne({
        where: { id: params.before, tournamentId },
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
        tournamentId,
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
      tournamentId,
      tournamentName: access.tournament.name,
      canSend: true,
      canClearForEveryone: access.organizer || access.staff,
      messages: rows.reverse().map((m) => this.toPublic(m, viewerId)),
    };
  }

  async inbox(_userId: string) {
    return [];
  }

  async unreadCount(_userId: string) {
    return 0;
  }

  async post(
    tournamentId: string,
    authorId: string,
    dto: PostChatMessageDto,
  ) {
    this.assertEnabled();
    const access = await this.requireAccess(tournamentId, authorId);
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
      this.realtime.interTeamRoom(tournamentId),
      RealtimeEvents.interTeamMessage,
      socketPayload,
    );

    const recipients = await this.recipientIds(tournamentId);
    const preview = `${socketPayload.authorPseudo ?? 'Quelqu’un'}: ${body}`.slice(
      0,
      140,
    );
    await Promise.all(
      recipients.map((userId) =>
        this.realtime.notifyUser({
          userId,
          event: RealtimeEvents.interTeamMessage,
          payload: socketPayload,
          skipPush: userId === authorId,
          push: {
            title: `Capitaines · ${access.tournament.name}`,
            body: preview,
            data: {
              type: 'inter_team_message',
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
    this.assertEnabled();
    const message = await this.messages.findOne({ where: { id: messageId } });
    if (!message || message.deletedAt) {
      throw new NotFoundException('Message introuvable');
    }
    const access = await this.requireAccess(message.tournamentId, actorId);
    const isAuthor = message.authorId === actorId;
    if (!isAuthor && !access.organizer && !access.staff) {
      throw new ForbiddenException(
        'Seul l’auteur, l’orga ou un admin peut supprimer ce message',
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
      this.realtime.interTeamRoom(message.tournamentId),
      RealtimeEvents.interTeamMessageDeleted,
      deletedPayload,
    );
    return { success: true, message: 'Message supprimé', id: messageId };
  }

  async clearForMe(tournamentId: string, userId: string) {
    this.assertEnabled();
    await this.requireAccess(tournamentId, userId);
    const receipt = await this.getReceipt(tournamentId, userId);
    const now = new Date();
    receipt.chatClearedAt = now;
    receipt.lastReadAt = now;
    await this.receipts.save(receipt);
    return { success: true };
  }

  async hideForMe(tournamentId: string, userId: string) {
    this.assertEnabled();
    await this.requireAccess(tournamentId, userId);
    const receipt = await this.getReceipt(tournamentId, userId);
    const now = new Date();
    receipt.chatHiddenAt = now;
    receipt.lastReadAt = now;
    await this.receipts.save(receipt);
    return { success: true };
  }

  async clearForEveryone(tournamentId: string, actorId: string) {
    this.assertEnabled();
    const access = await this.requireAccess(tournamentId, actorId);
    if (!access.organizer && !access.staff) {
      throw new ForbiddenException(
        'Seul l’organisateur peut vider le chat inter-équipes',
      );
    }
    const now = new Date();
    await this.messages
      .createQueryBuilder()
      .update(InterTeamChatMessage)
      .set({ deletedAt: now, deletedById: actorId })
      .where('tournament_id = :tournamentId', { tournamentId })
      .andWhere('deleted_at IS NULL')
      .execute();
    this.realtime.emitToRoom(
      this.realtime.interTeamRoom(tournamentId),
      RealtimeEvents.interTeamChatCleared,
      { tournamentId },
    );
    return { success: true };
  }

  private async requireAccess(tournamentId: string, userId: string) {
    const tournament = await this.tournaments.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    const captainTeam = await this.teams.findOne({
      where: { tournamentId, captainId: userId },
    });
    const tournamentMember = await this.tournamentMembers.findOne({
      where: { tournamentId, userId },
    });
    const user = await this.users.findOne({ where: { id: userId } });
    const staff =
      isStaff(user?.globalRole) ||
      (await actorCanManageTournaments(this.db, userId));
    const organizer =
      tournamentMember?.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === userId;
    if (!captainTeam && !organizer && !staff) {
      throw new ForbiddenException(
        'Seuls les capitaines, l’orga et les admins peuvent accéder au chat inter-équipes',
      );
    }
    return { tournament, captain: Boolean(captainTeam), organizer, staff };
  }

  private async accessibleTournaments(userId: string) {
    const captainTeams = await this.teams.find({
      where: { captainId: userId },
    });
    const organized = await this.tournamentMembers.find({
      where: { userId, role: TournamentMemberRole.ORGANIZER },
    });
    const created = await this.tournaments.find({
      where: { createdById: userId },
    });
    const ids = new Set([
      ...captainTeams.map((t) => t.tournamentId),
      ...organized.map((m) => m.tournamentId),
      ...created.map((t) => t.id),
    ]);
    if (ids.size === 0) return [];
    return this.tournaments.find({
      where: [...ids].map((id) => ({ id })),
    });
  }

  private async getReceipt(tournamentId: string, userId: string) {
    const existing = await this.receipts.findOne({
      where: { tournamentId, userId },
    });
    if (existing) return existing;
    return this.receipts.save(
      this.receipts.create({
        tournamentId,
        userId,
        lastReadAt: null,
        chatClearedAt: null,
        chatHiddenAt: null,
      }),
    );
  }

  private async unreadFor(
    tournamentId: string,
    userId: string,
    receipt: InterTeamChatReceipt | null,
  ) {
    if (receipt?.chatHiddenAt) return 0;
    const qb = this.messages
      .createQueryBuilder('m')
      .where('m.tournament_id = :tournamentId', { tournamentId })
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

  private async recipientIds(tournamentId: string) {
    const teams = await this.teams.find({ where: { tournamentId } });
    const ids = new Set<string>();
    for (const team of teams) {
      if (team.captainId) ids.add(team.captainId);
    }
    const organizers = await this.tournamentMembers.find({
      where: { tournamentId, role: TournamentMemberRole.ORGANIZER },
    });
    for (const row of organizers) ids.add(row.userId);
    const tournament = await this.tournaments.findOne({
      where: { id: tournamentId },
    });
    if (tournament?.createdById) ids.add(tournament.createdById);
    return [...ids];
  }

  private toPublic(message: InterTeamChatMessage, viewerId: string) {
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
    message: ReturnType<InterTeamChatService['toPublic']>,
  ) {
    const { isMine: _isMine, ...rest } = message;
    return rest;
  }
}
