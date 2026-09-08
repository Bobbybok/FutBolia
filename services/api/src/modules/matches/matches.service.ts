import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import {
  MatchStatus,
  TournamentMemberRole,
  TournamentStatus,
} from '../../common/enums';
import { Tournament } from '../tournaments/entities/tournament.entity';
import { TournamentMember } from '../tournaments/entities/tournament-member.entity';
import { Team } from '../teams/entities/team.entity';
import { Match } from './entities/match.entity';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';

@Injectable()
export class MatchesService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get matches(): Repository<Match> {
    return this.db.getRepository(Match);
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

  async listByTournament(tournamentId: string, viewerId: string) {
    await this.requireParticipant(tournamentId, viewerId);
    const rows = await this.matches.find({
      where: { tournamentId },
      relations: { homeTeam: true, awayTeam: true },
      order: { scheduledAt: 'ASC', createdAt: 'ASC' },
    });
    return rows.map((m) => this.toPublic(m));
  }

  async getById(matchId: string, viewerId: string) {
    const match = await this.matches.findOne({
      where: { id: matchId },
      relations: { homeTeam: true, awayTeam: true },
    });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    await this.requireParticipant(match.tournamentId, viewerId);
    return this.toPublic(match);
  }

  async create(tournamentId: string, actorId: string, dto: CreateMatchDto) {
    const tournament = await this.requireTournament(tournamentId);
    await this.requireOrganizer(tournament, actorId);
    this.assertTournamentAllowsMatches(tournament);

    if (dto.homeTeamId === dto.awayTeamId) {
      throw new BadRequestException('Une équipe ne peut pas jouer contre elle-même');
    }

    const [home, away] = await Promise.all([
      this.teams.findOne({ where: { id: dto.homeTeamId, tournamentId } }),
      this.teams.findOne({ where: { id: dto.awayTeamId, tournamentId } }),
    ]);
    if (!home || !away) {
      throw new BadRequestException(
        'Les deux équipes doivent appartenir à ce tournoi',
      );
    }

    const match = await this.matches.save(
      this.matches.create({
        tournamentId,
        homeTeamId: dto.homeTeamId,
        awayTeamId: dto.awayTeamId,
        scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : null,
        status: MatchStatus.SCHEDULED,
        homeScore: null,
        awayScore: null,
        createdById: actorId,
      }),
    );

    await this.markTournamentInProgress(tournament);
    return this.getById(match.id, actorId);
  }

  async generateRoundRobin(tournamentId: string, actorId: string) {
    const tournament = await this.requireTournament(tournamentId);
    await this.requireOrganizer(tournament, actorId);
    this.assertTournamentAllowsMatches(tournament);

    const teams = await this.teams.find({
      where: { tournamentId },
      order: { createdAt: 'ASC' },
    });
    if (teams.length < 2) {
      throw new BadRequestException(
        'Au moins 2 équipes sont nécessaires pour générer le calendrier',
      );
    }

    const existing = await this.matches.find({
      where: {
        tournamentId,
        status: Not(MatchStatus.CANCELLED),
      },
    });
    const pairKey = (a: string, b: string) =>
      [a, b].sort().join(':');
    const existingPairs = new Set(
      existing.map((m) => pairKey(m.homeTeamId, m.awayTeamId)),
    );

    const created: Match[] = [];
    for (let i = 0; i < teams.length; i++) {
      for (let j = i + 1; j < teams.length; j++) {
        const home = teams[i];
        const away = teams[j];
        const key = pairKey(home.id, away.id);
        if (existingPairs.has(key)) continue;

        const match = await this.matches.save(
          this.matches.create({
            tournamentId,
            homeTeamId: home.id,
            awayTeamId: away.id,
            scheduledAt: null,
            status: MatchStatus.SCHEDULED,
            homeScore: null,
            awayScore: null,
            createdById: actorId,
          }),
        );
        existingPairs.add(key);
        created.push(match);
      }
    }

    if (created.length > 0) {
      await this.markTournamentInProgress(tournament);
    }

    const all = await this.listByTournament(tournamentId, actorId);
    return {
      createdCount: created.length,
      matches: all,
    };
  }

  async update(matchId: string, actorId: string, dto: UpdateMatchDto) {
    const match = await this.matches.findOne({ where: { id: matchId } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    const tournament = await this.requireTournament(match.tournamentId);
    await this.requireOrganizer(tournament, actorId);
    this.assertTournamentAllowsMatches(tournament);

    if (match.status === MatchStatus.CANCELLED && dto.status !== MatchStatus.SCHEDULED) {
      throw new BadRequestException('Ce match est annulé');
    }

    if (dto.scheduledAt !== undefined) {
      match.scheduledAt = dto.scheduledAt ? new Date(dto.scheduledAt) : null;
    }

    if (dto.homeScore !== undefined) match.homeScore = dto.homeScore;
    if (dto.awayScore !== undefined) match.awayScore = dto.awayScore;

    if (dto.status !== undefined) {
      if (dto.status === MatchStatus.FINISHED) {
        const home = dto.homeScore ?? match.homeScore;
        const away = dto.awayScore ?? match.awayScore;
        if (home == null || away == null) {
          throw new BadRequestException(
            'Les deux scores sont requis pour terminer le match',
          );
        }
        if (home < 0 || away < 0) {
          throw new BadRequestException('Les scores doivent être positifs');
        }
        match.homeScore = home;
        match.awayScore = away;
      }
      if (dto.status === MatchStatus.SCHEDULED) {
        // Reopen: keep scores if present, or clear — keep scores for correction flow
      }
      if (dto.status === MatchStatus.CANCELLED) {
        match.homeScore = null;
        match.awayScore = null;
      }
      match.status = dto.status;
    } else if (
      match.homeScore != null &&
      match.awayScore != null &&
      match.status === MatchStatus.SCHEDULED
    ) {
      // Entering both scores finishes the match
      match.status = MatchStatus.FINISHED;
    }

    await this.matches.save(match);
    return this.getById(matchId, actorId);
  }

  async remove(matchId: string, actorId: string) {
    const match = await this.matches.findOne({ where: { id: matchId } });
    if (!match) {
      throw new NotFoundException('Match introuvable');
    }
    const tournament = await this.requireTournament(match.tournamentId);
    await this.requireOrganizer(tournament, actorId);

    if (match.status === MatchStatus.FINISHED) {
      throw new BadRequestException(
        'Impossible de supprimer un match terminé. Annulez-le à la place.',
      );
    }

    await this.matches.remove(match);
    return { success: true, message: 'Match supprimé', id: matchId };
  }

  async cancel(matchId: string, actorId: string) {
    return this.update(matchId, actorId, { status: MatchStatus.CANCELLED });
  }

  async standings(tournamentId: string, viewerId: string) {
    await this.requireParticipant(tournamentId, viewerId);
    const teams = await this.teams.find({
      where: { tournamentId },
      order: { name: 'ASC' },
    });
    const finished = await this.matches.find({
      where: { tournamentId, status: MatchStatus.FINISHED },
    });

    type Row = {
      teamId: string;
      teamName: string;
      played: number;
      won: number;
      drawn: number;
      lost: number;
      goalsFor: number;
      goalsAgainst: number;
      goalDiff: number;
      points: number;
    };

    const table = new Map<string, Row>();
    for (const team of teams) {
      table.set(team.id, {
        teamId: team.id,
        teamName: team.name,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        goalDiff: 0,
        points: 0,
      });
    }

    for (const match of finished) {
      const home = table.get(match.homeTeamId);
      const away = table.get(match.awayTeamId);
      if (!home || !away || match.homeScore == null || match.awayScore == null) {
        continue;
      }

      home.played += 1;
      away.played += 1;
      home.goalsFor += match.homeScore;
      home.goalsAgainst += match.awayScore;
      away.goalsFor += match.awayScore;
      away.goalsAgainst += match.homeScore;

      if (match.homeScore > match.awayScore) {
        home.won += 1;
        home.points += 3;
        away.lost += 1;
      } else if (match.homeScore < match.awayScore) {
        away.won += 1;
        away.points += 3;
        home.lost += 1;
      } else {
        home.drawn += 1;
        away.drawn += 1;
        home.points += 1;
        away.points += 1;
      }
    }

    const rows = [...table.values()].map((r) => ({
      ...r,
      goalDiff: r.goalsFor - r.goalsAgainst,
    }));

    rows.sort((a, b) => {
      if (b.points !== a.points) return b.points - a.points;
      if (b.goalDiff !== a.goalDiff) return b.goalDiff - a.goalDiff;
      if (b.goalsFor !== a.goalsFor) return b.goalsFor - a.goalsFor;
      return a.teamName.localeCompare(b.teamName, 'fr');
    });

    return rows.map((r, index) => ({
      rank: index + 1,
      ...r,
    }));
  }

  private async markTournamentInProgress(tournament: Tournament) {
    if (tournament.status === TournamentStatus.REGISTRATION_OPEN) {
      tournament.status = TournamentStatus.IN_PROGRESS;
      await this.tournaments.save(tournament);
    }
  }

  private assertTournamentAllowsMatches(tournament: Tournament) {
    if (
      tournament.status === TournamentStatus.FINISHED ||
      tournament.status === TournamentStatus.CANCELLED
    ) {
      throw new BadRequestException(
        'Impossible de gérer les matchs d’un tournoi terminé ou annulé',
      );
    }
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
        "Seul l'organisateur peut gérer les matchs",
      );
    }
  }

  private toPublic(match: Match) {
    return {
      id: match.id,
      tournamentId: match.tournamentId,
      homeTeamId: match.homeTeamId,
      awayTeamId: match.awayTeamId,
      homeTeamName: match.homeTeam?.name ?? null,
      awayTeamName: match.awayTeam?.name ?? null,
      scheduledAt: match.scheduledAt,
      status: match.status,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      createdById: match.createdById,
      createdAt: match.createdAt,
    };
  }
}
