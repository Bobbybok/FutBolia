import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, In, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  EventInviteStatus,
  EventInviteTargetType,
  TournamentMemberRole,
  TournamentVisibility,
  toPlatformRole,
} from '../../common/enums';
import { FriendsService } from '../friends/friends.service';
import { TournamentsService } from '../tournaments/tournaments.service';
import { PickupMatchesService } from '../pickup-matches/pickup-matches.service';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { PickupMatch } from '../pickup-matches/entities/pickup-match.entity';
import { User } from '../users/entities/user.entity';
import { EventInvite } from './entities/event-invite.entity';
import { CreateEventInvitesDto } from './dto/create-event-invites.dto';

@Injectable()
export class InvitesService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly friends: FriendsService,
    private readonly tournaments: TournamentsService,
    private readonly pickupMatches: PickupMatchesService,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get invites(): Repository<EventInvite> {
    return this.db.getRepository(EventInvite);
  }

  private get tournamentsRepo(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get tournamentMembers(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  private get pickupMatchesRepo(): Repository<PickupMatch> {
    return this.db.getRepository(PickupMatch);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  async create(inviterId: string, dto: CreateEventInvitesDto) {
    await this.assertCanInvite(inviterId, dto.targetType, dto.targetId);

    const uniqueFriendIds = [...new Set(dto.friendIds)].filter(
      (id) => id !== inviterId,
    );
    if (uniqueFriendIds.length === 0) {
      throw new BadRequestException('Sélectionne au moins un ami');
    }

    const created: EventInvite[] = [];
    for (const friendId of uniqueFriendIds) {
      await this.friends.assertFriends(inviterId, friendId);

      const existing = await this.invites.findOne({
        where: {
          targetType: dto.targetType,
          targetId: dto.targetId,
          inviteeId: friendId,
        },
      });

      if (existing?.status === EventInviteStatus.PENDING) {
        continue;
      }
      if (existing?.status === EventInviteStatus.ACCEPTED) {
        continue;
      }

      if (existing) {
        existing.status = EventInviteStatus.PENDING;
        existing.inviterId = inviterId;
        existing.respondedAt = null;
        created.push(await this.invites.save(existing));
        continue;
      }

      created.push(
        await this.invites.save(
          this.invites.create({
            targetType: dto.targetType,
            targetId: dto.targetId,
            inviterId,
            inviteeId: friendId,
            status: EventInviteStatus.PENDING,
          }),
        ),
      );
    }

    return {
      success: true,
      invited: created.length,
      invites: await Promise.all(created.map((row) => this.toPublic(row))),
    };
  }

  async listIncoming(userId: string) {
    const rows = await this.invites.find({
      where: { inviteeId: userId, status: EventInviteStatus.PENDING },
      relations: { inviter: { profile: true } },
      order: { createdAt: 'DESC' },
    });
    return Promise.all(rows.map((row) => this.toPublic(row)));
  }

  async listOutgoingForTarget(
    userId: string,
    targetType: EventInviteTargetType,
    targetId: string,
  ) {
    await this.assertCanInvite(userId, targetType, targetId);
    const rows = await this.invites.find({
      where: {
        targetType,
        targetId,
        status: In([EventInviteStatus.PENDING, EventInviteStatus.ACCEPTED]),
      },
      relations: { invitee: { profile: true } },
      order: { createdAt: 'DESC' },
    });
    return Promise.all(rows.map((row) => this.toPublic(row)));
  }

  async accept(inviteId: string, userId: string) {
    const invite = await this.requireInvite(inviteId);
    if (invite.inviteeId !== userId) {
      throw new ForbiddenException('Cette invitation ne t’est pas destinée');
    }
    if (invite.status !== EventInviteStatus.PENDING) {
      throw new BadRequestException('Invitation déjà traitée');
    }

    if (invite.targetType === EventInviteTargetType.TOURNAMENT) {
      await this.tournaments.join(invite.targetId, userId, {
        viaInvite: true,
      });
    } else {
      await this.pickupMatches.join(invite.targetId, userId, {
        viaInvite: true,
      });
    }

    invite.status = EventInviteStatus.ACCEPTED;
    invite.respondedAt = new Date();
    await this.invites.save(invite);
    return this.toPublic(invite);
  }

  async decline(inviteId: string, userId: string) {
    const invite = await this.requireInvite(inviteId);
    if (invite.inviteeId !== userId) {
      throw new ForbiddenException('Cette invitation ne t’est pas destinée');
    }
    if (invite.status !== EventInviteStatus.PENDING) {
      throw new BadRequestException('Invitation déjà traitée');
    }
    invite.status = EventInviteStatus.DECLINED;
    invite.respondedAt = new Date();
    await this.invites.save(invite);
    return { success: true };
  }

  async cancel(inviteId: string, userId: string) {
    const invite = await this.requireInvite(inviteId);
    if (invite.inviterId !== userId) {
      throw new ForbiddenException('Seul l’expéditeur peut annuler');
    }
    if (invite.status !== EventInviteStatus.PENDING) {
      throw new BadRequestException('Invitation déjà traitée');
    }
    invite.status = EventInviteStatus.CANCELLED;
    invite.respondedAt = new Date();
    await this.invites.save(invite);
    return { success: true };
  }

  async hasPendingInvite(
    targetType: EventInviteTargetType,
    targetId: string,
    inviteeId: string,
  ) {
    const row = await this.invites.findOne({
      where: {
        targetType,
        targetId,
        inviteeId,
        status: EventInviteStatus.PENDING,
      },
    });
    return Boolean(row);
  }

  private async assertCanInvite(
    userId: string,
    targetType: EventInviteTargetType,
    targetId: string,
  ) {
    if (targetType === EventInviteTargetType.TOURNAMENT) {
      const tournament = await this.tournamentsRepo.findOne({
        where: { id: targetId },
      });
      if (!tournament) {
        throw new NotFoundException('Tournoi introuvable');
      }
      if (tournament.visibility !== TournamentVisibility.PRIVATE) {
        throw new BadRequestException(
          'Les invitations sont réservées aux tournois privés',
        );
      }
      const member = await this.tournamentMembers.findOne({
        where: { tournamentId: targetId, userId },
      });
      const isOrganizer =
        tournament.createdById === userId ||
        member?.role === TournamentMemberRole.ORGANIZER;
      if (!isOrganizer) {
        throw new ForbiddenException(
          'Seul l’organisateur peut inviter des amis',
        );
      }
      return;
    }

    const match = await this.pickupMatchesRepo.findOne({
      where: { id: targetId },
    });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    if (match.visibility !== TournamentVisibility.PRIVATE) {
      throw new BadRequestException(
        'Les invitations sont réservées aux matchs privés',
      );
    }
    if (match.createdById !== userId) {
      throw new ForbiddenException('Seul l’hôte peut inviter des amis');
    }
  }

  private async requireInvite(id: string) {
    const invite = await this.invites.findOne({
      where: { id },
      relations: {
        inviter: { profile: true },
        invitee: { profile: true },
      },
    });
    if (!invite) {
      throw new NotFoundException('Invitation introuvable');
    }
    return invite;
  }

  private async toPublic(invite: EventInvite) {
    if (!invite.inviter) {
      invite.inviter = (await this.users.findOne({
        where: { id: invite.inviterId },
        relations: { profile: true },
      }))!;
    }
    if (!invite.invitee) {
      invite.invitee = (await this.users.findOne({
        where: { id: invite.inviteeId },
        relations: { profile: true },
      }))!;
    }

    const targetLabel = await this.resolveTargetLabel(
      invite.targetType,
      invite.targetId,
    );

    return {
      id: invite.id,
      targetType: invite.targetType,
      targetId: invite.targetId,
      targetLabel,
      status: invite.status,
      createdAt: invite.createdAt,
      respondedAt: invite.respondedAt,
      inviter: {
        id: invite.inviter.id,
        pseudo: invite.inviter.profile?.pseudo ?? '',
        role: toPlatformRole(invite.inviter.globalRole),
      },
      invitee: {
        id: invite.invitee.id,
        pseudo: invite.invitee.profile?.pseudo ?? '',
        role: toPlatformRole(invite.invitee.globalRole),
      },
    };
  }

  private async resolveTargetLabel(
    targetType: EventInviteTargetType,
    targetId: string,
  ) {
    if (targetType === EventInviteTargetType.TOURNAMENT) {
      const t = await this.tournamentsRepo.findOne({ where: { id: targetId } });
      return t?.name ?? 'Tournoi';
    }
    const m = await this.pickupMatchesRepo.findOne({ where: { id: targetId } });
    return m ? `${m.location} · ${m.playersPerTeam}v${m.playersPerTeam}` : 'Match';
  }
}
