import { Injectable } from '@nestjs/common';
import { TournamentsService } from '../tournaments/tournaments.service';
import { PickupMatchesService } from '../pickup-matches/pickup-matches.service';

@Injectable()
export class DiscoveryService {
  constructor(
    private readonly tournaments: TournamentsService,
    private readonly pickups: PickupMatchesService,
  ) {}

  async nearby(params: {
    lat: number;
    lng: number;
    userId?: string;
  }) {
    const [tournaments, pickups] = await Promise.all([
      this.tournaments.list({
        lat: params.lat,
        lng: params.lng,
        userId: params.userId,
      }),
      this.pickups.list({
        lat: params.lat,
        lng: params.lng,
        userId: params.userId,
      }),
    ]);
    return {
      tournaments,
      pickups,
      lat: params.lat,
      lng: params.lng,
    };
  }
}
