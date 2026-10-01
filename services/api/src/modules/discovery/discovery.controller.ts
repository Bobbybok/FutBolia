import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import {
  parseCoord,
  parseNearbyRadiusKm,
} from '../../common/geo';
import { DiscoveryService } from './discovery.service';

@Controller('discovery')
export class DiscoveryController {
  constructor(private readonly discovery: DiscoveryService) {}

  @Get('nearby')
  @UseGuards(OptionalJwtAuthGuard)
  nearby(
    @Query('lat') lat: string | undefined,
    @Query('lng') lng: string | undefined,
    @Query('radiusKm') radiusKm: string | undefined,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    const parsedLat = parseCoord(lat);
    const parsedLng = parseCoord(lng);
    if (parsedLat == null || parsedLng == null) {
      return { tournaments: [], pickups: [], radiusKm: parseNearbyRadiusKm(radiusKm) };
    }
    return this.discovery.nearby({
      lat: parsedLat,
      lng: parsedLng,
      radiusKm: parseNearbyRadiusKm(radiusKm),
      userId: user?.id,
    });
  }
}
