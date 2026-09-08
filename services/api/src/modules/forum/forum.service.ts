import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { TournamentMemberRole } from '../../common/enums';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { ForumPost } from './entities/forum-post.entity';
import { ForumReply } from './entities/forum-reply.entity';
import { CreateForumPostDto } from './dto/create-forum-post.dto';
import { CreateForumReplyDto } from './dto/create-forum-reply.dto';

@Injectable()
export class ForumService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get posts(): Repository<ForumPost> {
    return this.db.getRepository(ForumPost);
  }

  private get replies(): Repository<ForumReply> {
    return this.db.getRepository(ForumReply);
  }

  private get tournaments(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get members(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  async listPosts(tournamentId: string, viewerId: string) {
    await this.requireParticipant(tournamentId, viewerId);
    const organizer = await this.isOrganizer(tournamentId, viewerId);
    const rows = await this.posts.find({
      where: { tournamentId },
      relations: { author: { profile: true } },
      order: { createdAt: 'DESC' },
    });

    const counts = await this.replies
      .createQueryBuilder('r')
      .select('r.post_id', 'postId')
      .addSelect('COUNT(*)', 'count')
      .where('r.post_id IN (:...ids)', {
        ids: rows.length
          ? rows.map((p) => p.id)
          : ['00000000-0000-0000-0000-000000000000'],
      })
      .groupBy('r.post_id')
      .getRawMany<{ postId: string; count: string }>();

    const countMap = new Map(counts.map((c) => [c.postId, Number(c.count)]));

    return rows.map((p) =>
      this.toPostPublic(p, countMap.get(p.id) ?? 0, viewerId, organizer),
    );
  }

  async getPost(postId: string, viewerId: string) {
    const post = await this.posts.findOne({
      where: { id: postId },
      relations: { author: { profile: true } },
    });
    if (!post) {
      throw new NotFoundException('Publication introuvable');
    }
    await this.requireParticipant(post.tournamentId, viewerId);
    const organizer = await this.isOrganizer(post.tournamentId, viewerId);

    const replies = await this.replies.find({
      where: { postId },
      relations: { author: { profile: true } },
      order: { createdAt: 'ASC' },
    });

    return {
      ...this.toPostPublic(post, replies.length, viewerId, organizer),
      replies: replies.map((r) =>
        this.toReplyPublic(r, viewerId, organizer),
      ),
    };
  }

  async createPost(
    tournamentId: string,
    authorId: string,
    dto: CreateForumPostDto,
  ) {
    await this.requireTournament(tournamentId);
    await this.requireParticipant(tournamentId, authorId);

    const post = await this.posts.save(
      this.posts.create({
        tournamentId,
        authorId,
        title: dto.title.trim(),
        body: dto.body.trim(),
      }),
    );

    return this.getPost(post.id, authorId);
  }

  async createReply(postId: string, authorId: string, dto: CreateForumReplyDto) {
    const post = await this.posts.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('Publication introuvable');
    }
    await this.requireParticipant(post.tournamentId, authorId);

    await this.replies.save(
      this.replies.create({
        postId,
        authorId,
        body: dto.body.trim(),
      }),
    );

    return this.getPost(postId, authorId);
  }

  async deletePost(postId: string, actorId: string) {
    const post = await this.posts.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('Publication introuvable');
    }
    await this.requireCanModerate(
      post.tournamentId,
      actorId,
      post.authorId,
    );
    await this.posts.remove(post);
    return { success: true, message: 'Publication supprimée', id: postId };
  }

  async deleteReply(replyId: string, actorId: string) {
    const reply = await this.replies.findOne({
      where: { id: replyId },
      relations: { post: true },
    });
    if (!reply || !reply.post) {
      throw new NotFoundException('Réponse introuvable');
    }
    await this.requireCanModerate(
      reply.post.tournamentId,
      actorId,
      reply.authorId,
    );
    const postId = reply.postId;
    await this.replies.remove(reply);
    return this.getPost(postId, actorId);
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
    const membership = await this.members.findOne({
      where: { tournamentId, userId },
    });
    if (!membership) {
      throw new ForbiddenException(
        'Seuls les participants du tournoi peuvent accéder au forum',
      );
    }
    return membership;
  }

  private async requireCanModerate(
    tournamentId: string,
    actorId: string,
    authorId: string,
  ) {
    if (actorId === authorId) return;
    const membership = await this.requireParticipant(tournamentId, actorId);
    const tournament = await this.requireTournament(tournamentId);
    const isOrganizer =
      membership.role === TournamentMemberRole.ORGANIZER ||
      tournament.createdById === actorId;
    if (!isOrganizer) {
      throw new ForbiddenException(
        'Seul l’auteur ou l’organisateur peut supprimer ce contenu',
      );
    }
  }

  private async isOrganizer(tournamentId: string, userId: string) {
    const tournament = await this.requireTournament(tournamentId);
    if (tournament.createdById === userId) return true;
    const membership = await this.members.findOne({
      where: {
        tournamentId,
        userId,
        role: TournamentMemberRole.ORGANIZER,
      },
    });
    return !!membership;
  }

  private toPostPublic(
    post: ForumPost,
    repliesCount: number,
    viewerId: string,
    isOrganizer: boolean,
  ) {
    return {
      id: post.id,
      tournamentId: post.tournamentId,
      title: post.title,
      body: post.body,
      authorId: post.authorId,
      authorPseudo: post.author?.profile?.pseudo ?? null,
      repliesCount,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      canDelete: post.authorId === viewerId || isOrganizer,
    };
  }

  private toReplyPublic(
    reply: ForumReply,
    viewerId: string,
    isOrganizer: boolean,
  ) {
    return {
      id: reply.id,
      postId: reply.postId,
      body: reply.body,
      authorId: reply.authorId,
      authorPseudo: reply.author?.profile?.pseudo ?? null,
      createdAt: reply.createdAt,
      canDelete: reply.authorId === viewerId || isOrganizer,
    };
  }
}
