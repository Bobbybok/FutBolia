import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  MercatoPlayerStatus,
  RecruitmentOfferStatus,
  TeamMemberSlot,
  TeamStatus,
  TournamentMemberRole,
  TournamentMode,
  TournamentStatus,
} from '../../common/enums';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { Team } from '../teams/entities/team.entity';
import { TeamMember } from '../teams/entities/team-member.entity';
import { RecruitmentOffer } from './entities/recruitment-offer.entity';
import { CreateOfferDto } from './dto/create-offer.dto';

@Injectable()
export class MercatoService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get tournaments(): Repository<Tournament> {
    return this.db.getRepository(Tournament);
  }

  private get tournamentMembers(): Repository<TournamentMember> {
    return this.db.getRepository(TournamentMember);
  }

  private get teams(): Repository<Team> {
    return this.db.getRepository(Team);
  }

  private get teamMembers(): Repository<TeamMember> {
    return this.db.getRepository(TeamMember);
  }

  private get offers(): Repository<RecruitmentOffer> {
    return this.db.getRepository(RecruitmentOffer);
  }

  async getBoard(tournamentId: string, viewerId: string) {
    const tournament = await this.requireSelectionTournament(tournamentId);
    await this.requireParticipant(tournamentId, viewerId);

    const members = await this.tournamentMembers.find({
      where: { tournamentId },
      relations: { user: { profile: true } },
      order: { joinedAt: 'ASC' },
    });

    const recruited = await this.teamMembers
      .createQueryBuilder('tm')
      .innerJoin(Team, 't', 't.id = tm.team_id')
      .where('t.tournament_id = :tournamentId', { tournamentId })
      .getMany();
    const recruitedIds = new Set(recruited.map((r) => r.userId));

    const pendingOffers = await this.offers.find({
      where: {
        tournamentId,
        status: RecruitmentOfferStatus.PENDING,
      },
    });

    const mySelectorTeams = await this.teams.find({
      where: { tournamentId, selectorId: viewerId },
    });
    const myTeamIds = new Set(mySelectorTeams.map((t) => t.id));

    return members.map((m) => {
        const playerPending = pendingOffers.filter(
          (o) => o.playerId === m.userId,
        );
        const myOffer = playerPending.find((o) => myTeamIds.has(o.teamId));

        let status: MercatoPlayerStatus = MercatoPlayerStatus.AVAILABLE;
        if (recruitedIds.has(m.userId)) {
          status = MercatoPlayerStatus.RECRUITED;
        } else if (myOffer) {
          status = MercatoPlayerStatus.OFFER_SENT;
        } else if (playerPending.length > 0) {
          status = MercatoPlayerStatus.IN_NEGOTIATION;
        }

        return {
          userId: m.userId,
          pseudo: m.user.profile?.pseudo ?? null,
          avatarUrl: m.user.profile?.avatarUrl ?? null,
          position: m.user.profile?.position ?? null,
          level: m.user.profile?.level ?? null,
          city: m.user.profile?.city ?? null,
          status,
          pendingOffersCount: playerPending.length,
          myOfferId: myOffer?.id ?? null,
          tournamentMode: tournament.mode,
        };
      });
  }

  async listMyOffers(viewerId: string, tournamentId?: string) {
    const where: {
      playerId: string;
      status: RecruitmentOfferStatus;
      tournamentId?: string;
    } = {
      playerId: viewerId,
      status: RecruitmentOfferStatus.PENDING,
    };
    if (tournamentId) where.tournamentId = tournamentId;

    const rows = await this.offers.find({
      where,
      relations: { team: true },
      order: { createdAt: 'DESC' },
    });

    return rows.map((o) => ({
      id: o.id,
      tournamentId: o.tournamentId,
      teamId: o.teamId,
      teamName: o.team?.name ?? null,
      selectorId: o.selectorId,
      status: o.status,
      createdAt: o.createdAt,
    }));
  }

  async createOffer(selectorId: string, dto: CreateOfferDto) {
    const team = await this.teams.findOne({ where: { id: dto.teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }

    const tournament = await this.requireSelectionTournament(team.tournamentId);
    if (
      tournament.status === TournamentStatus.FINISHED ||
      tournament.status === TournamentStatus.CANCELLED
    ) {
      throw new BadRequestException('Mercato indisponible pour ce tournoi');
    }

    if (team.selectorId !== selectorId) {
      const membership = await this.tournamentMembers.findOne({
        where: {
          tournamentId: team.tournamentId,
          userId: selectorId,
          role: TournamentMemberRole.ORGANIZER,
        },
      });
      if (!membership && tournament.createdById !== selectorId) {
        throw new ForbiddenException(
          'Seul le sélectionneur de l’équipe (ou l’organisateur) peut proposer un recrutement',
        );
      }
    }

    if (team.status === TeamStatus.VALIDATED) {
      throw new BadRequestException('Cette équipe est déjà validée');
    }

    await this.requireParticipant(team.tournamentId, dto.playerId);

    const alreadyInTeam = await this.teamMembers
      .createQueryBuilder('tm')
      .innerJoin(Team, 't', 't.id = tm.team_id')
      .where('t.tournament_id = :tournamentId', {
        tournamentId: team.tournamentId,
      })
      .andWhere('tm.user_id = :userId', { userId: dto.playerId })
      .getOne();
    if (alreadyInTeam) {
      throw new ConflictException('Ce joueur est déjà recruté dans ce tournoi');
    }

    const existing = await this.offers.findOne({
      where: {
        teamId: team.id,
        playerId: dto.playerId,
        status: RecruitmentOfferStatus.PENDING,
      },
    });
    if (existing) {
      throw new ConflictException('Une offre est déjà en cours pour ce joueur');
    }

    const slot = dto.slot ?? TeamMemberSlot.STARTER;
    await this.assertSlotCapacity(team.id, tournament, slot);

    const offer = await this.offers.save(
      this.offers.create({
        tournamentId: team.tournamentId,
        teamId: team.id,
        playerId: dto.playerId,
        selectorId,
        status: RecruitmentOfferStatus.PENDING,
      }),
    );

    return {
      id: offer.id,
      tournamentId: offer.tournamentId,
      teamId: offer.teamId,
      playerId: offer.playerId,
      status: offer.status,
      slot,
      createdAt: offer.createdAt,
    };
  }

  async acceptOffer(offerId: string, playerId: string) {
    return this.db.transaction(async (manager) => {
      const offerRepo = manager.getRepository(RecruitmentOffer);
      const teamRepo = manager.getRepository(Team);
      const teamMemberRepo = manager.getRepository(TeamMember);
      const tournamentRepo = manager.getRepository(Tournament);

      // Verrouille le joueur pour empêcher un double recrutement concurrent.
      await manager.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [
        playerId,
      ]);

      const offer = await offerRepo.findOne({ where: { id: offerId } });
      if (!offer || offer.status !== RecruitmentOfferStatus.PENDING) {
        throw new BadRequestException('Offre invalide ou déjà traitée');
      }
      if (offer.playerId !== playerId) {
        throw new ForbiddenException('Cette offre ne vous est pas destinée');
      }

      const alreadyInTeam = await teamMemberRepo
        .createQueryBuilder('tm')
        .innerJoin(Team, 't', 't.id = tm.team_id')
        .where('t.tournament_id = :tournamentId', {
          tournamentId: offer.tournamentId,
        })
        .andWhere('tm.user_id = :userId', { userId: playerId })
        .getOne();
      if (alreadyInTeam) {
        throw new ConflictException('Vous êtes déjà dans une équipe');
      }

      const team = await teamRepo.findOne({ where: { id: offer.teamId } });
      if (!team) {
        throw new NotFoundException('Équipe introuvable');
      }
      if (team.status === TeamStatus.VALIDATED) {
        throw new BadRequestException('Cette équipe est déjà validée');
      }

      const tournament = await tournamentRepo.findOneByOrFail({
        id: offer.tournamentId,
      });

      let slot = TeamMemberSlot.STARTER;
      const starters = await teamMemberRepo.count({
        where: { teamId: team.id, slot: TeamMemberSlot.STARTER },
      });
      if (starters >= tournament.startersCount) {
        const subs = await teamMemberRepo.count({
          where: { teamId: team.id, slot: TeamMemberSlot.SUBSTITUTE },
        });
        if (subs >= tournament.substitutesCount) {
          throw new BadRequestException('Effectif de l’équipe complet');
        }
        slot = TeamMemberSlot.SUBSTITUTE;
      }

      await teamMemberRepo.save(
        teamMemberRepo.create({
          teamId: team.id,
          userId: playerId,
          slot,
        }),
      );

      if (!team.captainId) {
        team.captainId = playerId;
      }

      const newStarters = await teamMemberRepo.count({
        where: { teamId: team.id, slot: TeamMemberSlot.STARTER },
      });
      const newSubs = await teamMemberRepo.count({
        where: { teamId: team.id, slot: TeamMemberSlot.SUBSTITUTE },
      });
      team.status =
        newStarters >= tournament.startersCount &&
        newSubs >= tournament.substitutesCount
          ? TeamStatus.COMPLETE
          : TeamStatus.FORMING;
      await teamRepo.save(team);

      offer.status = RecruitmentOfferStatus.ACCEPTED;
      offer.resolvedAt = new Date();
      await offerRepo.save(offer);

      await offerRepo.update(
        {
          tournamentId: offer.tournamentId,
          playerId,
          status: RecruitmentOfferStatus.PENDING,
        },
        {
          status: RecruitmentOfferStatus.CANCELLED,
          resolvedAt: new Date(),
        },
      );

      return {
        success: true,
        teamId: team.id,
        slot,
        message: 'Recrutement accepté',
      };
    });
  }

  async rejectOffer(offerId: string, playerId: string) {
    const offer = await this.offers.findOne({ where: { id: offerId } });
    if (!offer || offer.status !== RecruitmentOfferStatus.PENDING) {
      throw new BadRequestException('Offre invalide ou déjà traitée');
    }
    if (offer.playerId !== playerId) {
      throw new ForbiddenException('Cette offre ne vous est pas destinée');
    }

    offer.status = RecruitmentOfferStatus.REJECTED;
    offer.resolvedAt = new Date();
    await this.offers.save(offer);
    return { success: true, message: 'Offre refusée' };
  }

  async nominateSelector(
    tournamentId: string,
    organizerId: string,
    userId: string,
  ) {
    const tournament = await this.requireSelectionTournament(tournamentId);
    await this.requireOrganizer(tournament, organizerId);
    const membership = await this.requireParticipant(tournamentId, userId);

    if (membership.role === TournamentMemberRole.PLAYER) {
      membership.role = TournamentMemberRole.SELECTOR;
      await this.tournamentMembers.save(membership);
    }

    return {
      success: true,
      userId,
      role: membership.role,
    };
  }

  async assignSelectorToTeam(
    teamId: string,
    organizerId: string,
    selectorId: string,
  ) {
    const team = await this.teams.findOne({ where: { id: teamId } });
    if (!team) {
      throw new NotFoundException('Équipe introuvable');
    }
    const tournament = await this.requireSelectionTournament(team.tournamentId);
    await this.requireOrganizer(tournament, organizerId);
    await this.assertSelectorAvailable(
      team.tournamentId,
      selectorId,
      team.id,
    );
    await this.nominateSelector(team.tournamentId, organizerId, selectorId);

    team.selectorId = selectorId;
    await this.teams.save(team);
    return {
      id: team.id,
      selectorId: team.selectorId,
      name: team.name,
    };
  }

  private async requireSelectionTournament(tournamentId: string) {
    const tournament = await this.tournaments.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) {
      throw new NotFoundException('Tournoi introuvable');
    }
    if (tournament.mode !== TournamentMode.SELECTION) {
      throw new BadRequestException(
        'Le mercato est réservé aux tournois en mode Sélection',
      );
    }
    return tournament;
  }

  private async requireParticipant(tournamentId: string, userId: string) {
    const membership = await this.tournamentMembers.findOne({
      where: { tournamentId, userId },
    });
    if (!membership) {
      throw new ForbiddenException('Vous devez participer au tournoi');
    }
    return membership;
  }

  private async requireOrganizer(tournament: Tournament, userId: string) {
    const membership = await this.tournamentMembers.findOne({
      where: {
        tournamentId: tournament.id,
        userId,
        role: TournamentMemberRole.ORGANIZER,
      },
    });
    if (!membership && tournament.createdById !== userId) {
      throw new ForbiddenException(
        "Seul l'organisateur peut effectuer cette action",
      );
    }
  }

  private async assertSelectorAvailable(
    tournamentId: string,
    selectorId: string,
    excludeTeamId?: string,
  ) {
    const qb = this.teams
      .createQueryBuilder('t')
      .where('t.tournament_id = :tournamentId', { tournamentId })
      .andWhere('t.selector_id = :selectorId', { selectorId });
    if (excludeTeamId) {
      qb.andWhere('t.id != :excludeTeamId', { excludeTeamId });
    }
    const existing = await qb.getOne();
    if (existing) {
      throw new ConflictException(
        'Ce joueur est déjà sélectionneur d’une autre équipe dans ce tournoi',
      );
    }
  }

  private async assertSlotCapacity(
    teamId: string,
    tournament: Tournament,
    slot: TeamMemberSlot,
  ) {
    const count = await this.teamMembers.count({
      where: { teamId, slot },
    });
    const max =
      slot === TeamMemberSlot.STARTER
        ? tournament.startersCount
        : tournament.substitutesCount;
    if (count >= max) {
      throw new BadRequestException(
        slot === TeamMemberSlot.STARTER
          ? `Limite de titulaires atteinte (${max})`
          : `Limite de remplaçants atteinte (${max})`,
      );
    }
  }
}
