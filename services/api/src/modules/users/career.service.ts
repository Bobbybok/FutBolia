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
import { ProfileHiddenItemType, TournamentMemberRole } from '../../common/enums';
import {
  actorCanManageTournaments,
  actorCanManageUsers,
} from '../../common/staff-access';
import { HideCareerItemDto } from './dto/hide-career-item.dto';
import { ProfileHiddenItem } from './entities/profile-hidden-item.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { Team } from '../teams/entities/team.entity';
import { TeamMember } from '../teams/entities/team-member.entity';
import { Match } from '../matches/entities/match.entity';
import { PickupMatch } from '../pickup-matches/entities/pickup-match.entity';
import { PickupMatchMember } from '../pickup-matches/entities/pickup-match-member.entity';

export type CareerItem = {
  id: string;
  kind: 'tournament' | 'match' | 'pickup_match';
  name: string;
  date: string | null;
  role: 'player' | 'organizer' | 'captain' | 'selector' | 'host';
  hidden: boolean;
  canRemoveFromProfile: boolean;
  canDeleteEvent: boolean;
};

type CareerViewer = {
  viewerId: string;
  isOwner: boolean;
  canRemove: boolean;
  staffEvents: boolean;
  organizerTournamentIds: Set<string>;
};

export type CareerPayload = {
  stats: {
    tournaments: number;
    matches: number;
    asOrganizer: number;
    asCaptain: number;
  };
  tournaments: CareerItem[];
  matches: CareerItem[];
};

@Injectable()
export class CareerService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get hidden(): Repository<ProfileHiddenItem> {
    return this.db.getRepository(ProfileHiddenItem);
  }

  async build(
    userId: string,
    viewerId: string,
    includeHidden: boolean,
  ): Promise<CareerPayload> {
    const hiddenRows = await this.hidden.find({ where: { userId } });
    const hiddenSet = new Set(
      hiddenRows.map((row) => `${row.itemType}:${row.itemId}`),
    );
    const viewer = await this.viewerContext(viewerId, userId);

    const [tournamentItems, matchItems] = await Promise.all([
      this.listTournaments(userId, hiddenSet, viewer),
      this.listMatches(userId, hiddenSet, viewer),
    ]);

    const visibleTournaments = includeHidden
      ? tournamentItems
      : tournamentItems.filter((item) => !item.hidden);
    const visibleMatches = includeHidden
      ? matchItems
      : matchItems.filter((item) => !item.hidden);

    const sourceTournaments = includeHidden ? tournamentItems : visibleTournaments;
    const sourceMatches = includeHidden ? matchItems : visibleMatches;

    return {
      stats: {
        tournaments: sourceTournaments.length,
        matches: sourceMatches.length,
        asOrganizer: sourceTournaments.filter(
          (item) => item.role === 'organizer',
        ).length,
        asCaptain: [...sourceTournaments, ...sourceMatches].filter(
          (item) => item.role === 'captain',
        ).length,
      },
      tournaments: visibleTournaments,
      matches: visibleMatches,
    };
  }

  async setHidden(
    userId: string,
    dto: HideCareerItemDto,
    viewerId = userId,
  ) {
    await this.assertOwnsItem(userId, dto.itemType, dto.itemId);
    const existing = await this.hidden.findOne({
      where: {
        userId,
        itemType: dto.itemType,
        itemId: dto.itemId,
      },
    });

    if (dto.hidden) {
      if (!existing) {
        await this.hidden.save(
          this.hidden.create({
            userId,
            itemType: dto.itemType,
            itemId: dto.itemId,
          }),
        );
      }
    } else if (existing) {
      await this.hidden.remove(existing);
    }

    return this.build(userId, viewerId, viewerId === userId);
  }

  async removeFromProfile(
    actorId: string,
    targetUserId: string,
    itemType: ProfileHiddenItemType,
    itemId: string,
  ) {
    const viewer = await this.viewerContext(actorId, targetUserId);
    if (!viewer.canRemove) {
      throw new ForbiddenException(
        'Tu ne peux retirer un élément que de ton profil (ou en tant qu’admin)',
      );
    }
    return this.setHidden(
      targetUserId,
      {
        itemType,
        itemId,
        hidden: true,
      },
      actorId,
    );
  }

  private async viewerContext(
    viewerId: string,
    profileUserId: string,
  ): Promise<CareerViewer> {
    const staffEvents = await actorCanManageTournaments(this.db, viewerId);
    const staffUsers = await actorCanManageUsers(this.db, viewerId);
    const isOwner = viewerId === profileUserId;
    const organizerRows = await this.db.getRepository(TournamentMember).find({
      where: { userId: viewerId, role: TournamentMemberRole.ORGANIZER },
    });
    const created = await this.db.getRepository(Tournament).find({
      where: { createdById: viewerId },
    });
    return {
      viewerId,
      isOwner,
      canRemove: isOwner || staffEvents || staffUsers,
      staffEvents,
      organizerTournamentIds: new Set([
        ...organizerRows.map((row) => row.tournamentId),
        ...created.map((row) => row.id),
      ]),
    };
  }

  private async assertOwnsItem(
    userId: string,
    itemType: ProfileHiddenItemType,
    itemId: string,
  ) {
    if (itemType === ProfileHiddenItemType.TOURNAMENT) {
      const member = await this.db.getRepository(TournamentMember).findOne({
        where: { userId, tournamentId: itemId },
      });
      const tournament = await this.db.getRepository(Tournament).findOne({
        where: { id: itemId, createdById: userId },
      });
      if (!member && !tournament) {
        throw new NotFoundException('Tournoi introuvable sur ce profil');
      }
      return;
    }

    if (itemType === ProfileHiddenItemType.MATCH) {
      const match = await this.db.getRepository(Match).findOne({
        where: { id: itemId },
      });
      if (!match) {
        throw new NotFoundException('Match introuvable');
      }
      const inTeam = await this.db.getRepository(TeamMember).exist({
        where: [
          { userId, teamId: match.homeTeamId },
          { userId, teamId: match.awayTeamId },
        ],
      });
      const captain = await this.db.getRepository(Team).exist({
        where: [
          { id: match.homeTeamId, captainId: userId },
          { id: match.awayTeamId, captainId: userId },
        ],
      });
      if (!inTeam && !captain) {
        throw new BadRequestException('Ce match n’est pas sur ton profil');
      }
      return;
    }

    const pickup = await this.db.getRepository(PickupMatch).findOne({
      where: { id: itemId },
    });
    if (!pickup) {
      throw new NotFoundException('Match libre introuvable');
    }
    const member = await this.db.getRepository(PickupMatchMember).exist({
      where: { userId, matchId: itemId },
    });
    if (!member && pickup.createdById !== userId) {
      throw new BadRequestException('Ce match n’est pas sur ton profil');
    }
  }

  private async listTournaments(
    userId: string,
    hiddenSet: Set<string>,
    viewer: CareerViewer,
  ): Promise<CareerItem[]> {
    const members = await this.db.getRepository(TournamentMember).find({
      where: { userId },
      relations: { tournament: true },
    });
    const organized = await this.db.getRepository(Tournament).find({
      where: { createdById: userId },
    });
    const captainTeams = await this.db.getRepository(Team).find({
      where: { captainId: userId },
    });
    const captainTournamentIds = new Set(
      captainTeams.map((team) => team.tournamentId),
    );

    const byId = new Map<string, Tournament>();
    for (const member of members) {
      if (member.tournament) byId.set(member.tournament.id, member.tournament);
    }
    for (const tournament of organized) {
      byId.set(tournament.id, tournament);
    }

    const roleByTournament = new Map<string, CareerItem['role']>();
    for (const member of members) {
      roleByTournament.set(
        member.tournamentId,
        this.memberRole(member.role, member.tournamentId, organized, captainTournamentIds),
      );
    }
    for (const tournament of organized) {
      roleByTournament.set(tournament.id, 'organizer');
    }

    return [...byId.values()]
      .map((tournament) => {
        const role = roleByTournament.get(tournament.id) ?? 'player';
        return {
          id: tournament.id,
          kind: 'tournament' as const,
          name: tournament.name,
          date: this.toIso(tournament.startsAt ?? tournament.createdAt),
          role,
          hidden: hiddenSet.has(
            `${ProfileHiddenItemType.TOURNAMENT}:${tournament.id}`,
          ),
          canRemoveFromProfile: viewer.canRemove,
          canDeleteEvent: false,
        };
      })
      .sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
  }

  private memberRole(
    role: string,
    tournamentId: string,
    organized: Tournament[],
    captainTournamentIds: Set<string>,
  ): CareerItem['role'] {
    if (
      role === 'organizer' ||
      organized.some((tournament) => tournament.id === tournamentId)
    ) {
      return 'organizer';
    }
    if (role === 'captain' || captainTournamentIds.has(tournamentId)) {
      return 'captain';
    }
    if (role === 'selector') return 'selector';
    return 'player';
  }

  private async listMatches(
    userId: string,
    hiddenSet: Set<string>,
    viewer: CareerViewer,
  ): Promise<CareerItem[]> {
    const teamMembers = await this.db.getRepository(TeamMember).find({
      where: { userId },
    });
    const captainTeams = await this.db.getRepository(Team).find({
      where: { captainId: userId },
    });
    const teamIds = [
      ...new Set([
        ...teamMembers.map((member) => member.teamId),
        ...captainTeams.map((team) => team.id),
      ]),
    ];
    const captainTeamIds = new Set(captainTeams.map((team) => team.id));

    const tournamentMatches =
      teamIds.length === 0
        ? []
        : await this.db.getRepository(Match).find({
            where: [{ homeTeamId: In(teamIds) }, { awayTeamId: In(teamIds) }],
            relations: { homeTeam: true, awayTeam: true, tournament: true },
          });

    const pickupMembers = await this.db.getRepository(PickupMatchMember).find({
      where: { userId },
      relations: { match: true },
    });
    const hostedPickups = await this.db.getRepository(PickupMatch).find({
      where: { createdById: userId },
    });

    const items: CareerItem[] = [];

    for (const match of tournamentMatches) {
      const myTeamId = teamIds.includes(match.homeTeamId)
        ? match.homeTeamId
        : match.awayTeamId;
      const role: CareerItem['role'] = captainTeamIds.has(myTeamId)
        ? 'captain'
        : 'player';
      const home = match.homeTeam?.name ?? 'Équipe A';
      const away = match.awayTeam?.name ?? 'Équipe B';
      items.push({
        id: match.id,
        kind: 'match',
        name: `${home} vs ${away}`,
        date: this.toIso(match.scheduledAt ?? match.createdAt),
        role,
        hidden: hiddenSet.has(`${ProfileHiddenItemType.MATCH}:${match.id}`),
        canRemoveFromProfile: viewer.canRemove,
        canDeleteEvent: false,
      });
    }

    const pickupById = new Map<string, PickupMatch>();
    for (const member of pickupMembers) {
      if (member.match) pickupById.set(member.match.id, member.match);
    }
    for (const pickup of hostedPickups) {
      pickupById.set(pickup.id, pickup);
    }

    for (const pickup of pickupById.values()) {
      items.push({
        id: pickup.id,
        kind: 'pickup_match',
        name: pickup.location,
        date: this.toIso(pickup.scheduledAt),
        role: pickup.createdById === userId ? 'host' : 'player',
        hidden: hiddenSet.has(
          `${ProfileHiddenItemType.PICKUP_MATCH}:${pickup.id}`,
        ),
        canRemoveFromProfile: viewer.canRemove,
        canDeleteEvent: false,
      });
    }

    return items.sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
  }

  private toIso(value: Date | null | undefined): string | null {
    if (!value) return null;
    return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
  }
}
