import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, IsNull, LessThan, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { TournamentMemberRole } from '../../common/enums';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { TournamentChatMessage } from './entities/tournament-chat-message.entity';
import { PostChatMessageDto } from './dto/post-chat-message.dto';

@Injectable()
export class ChatService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
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

  async list(
    tournamentId: string,
    viewerId: string,
    params?: { before?: string; limit?: number },
  ) {
    await this.requireParticipant(tournamentId, viewerId);

    const limit = Math.min(Math.max(params?.limit ?? 50, 1), 100);

    let beforeDate: Date | undefined;
    if (params?.before) {
      const cursor = await this.messages.findOne({
        where: { id: params.before, tournamentId },
      });
      beforeDate = cursor?.createdAt;
    }

    const rows = await this.messages.find({
      where: beforeDate
        ? {
            tournamentId,
            deletedAt: IsNull(),
            createdAt: LessThan(beforeDate),
          }
        : {
            tournamentId,
            deletedAt: IsNull(),
          },
      relations: { author: { profile: true } },
      order: { createdAt: 'DESC' },
      take: limit,
    });

    return rows.reverse().map((m) => this.toPublic(m, viewerId));
  }

  async post(
    tournamentId: string,
    authorId: string,
    dto: PostChatMessageDto,
  ) {
    await this.requireParticipant(tournamentId, authorId);
    await this.requireTournament(tournamentId);

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
    return this.toPublic(full!, authorId);
  }

  async remove(messageId: string, actorId: string) {
    const message = await this.messages.findOne({ where: { id: messageId } });
    if (!message || message.deletedAt) {
      throw new NotFoundException('Message introuvable');
    }

    const membership = await this.requireParticipant(
      message.tournamentId,
      actorId,
    );
    const tournament = await this.requireTournament(message.tournamentId);
    const isOrganizer =
      membership.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === actorId;
    const isAuthor = message.authorId === actorId;

    if (!isAuthor && !isOrganizer) {
      throw new ForbiddenException(
        'Seul l’auteur ou l’organisateur peut supprimer ce message',
      );
    }

    message.deletedAt = new Date();
    message.deletedById = actorId;
    await this.messages.save(message);

    return { success: true, message: 'Message supprimé', id: messageId };
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
      body: message.body,
      createdAt: message.createdAt,
      isMine: message.authorId === viewerId,
    };
  }
}
