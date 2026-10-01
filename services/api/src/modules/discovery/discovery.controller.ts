import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { parseCoord } from '../../common/geo';
import { DiscoveryService } from './discovery.service';

@Controller('discovery')
export class DiscoveryController {
  constructor(private readonly discovery: DiscoveryService) {}

  @Get('nearby')
  @UseGuards(OptionalJwtAuthGuard)
  nearby(
    @Query('lat') lat: string | undefined,
    @Query('lng') lng: string | undefined,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    const parsedLat = parseCoord(lat);
    const parsedLng = parseCoord(lng);
    if (parsedLat == null || parsedLng == null) {
      return { tournaments: [], pickups: [] };
    }
    return this.discovery.nearby({
      lat: parsedLat,
      lng: parsedLng,
      userId: user?.id,
    });
  }
}
