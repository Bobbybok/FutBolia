import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PickupMatchesService } from './pickup-matches.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreatePickupMatchDto } from './dto/create-pickup-match.dto';
import { JoinPickupMatchDto } from './dto/join-pickup-match.dto';
import { ScorePickupMatchDto } from './dto/score-pickup-match.dto';

@Controller('pickup-matches')
export class PickupMatchesController {
  constructor(private readonly pickupMatchesService: PickupMatchesService) {}

  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  list(
    @Query('mine') mine: string | undefined,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.pickupMatchesService.list({
      mine: mine === 'true' || mine === '1',
      userId: user?.id,
    });
  }

  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  getOne(
    @Param('id') id: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.pickupMatchesService.getById(id, user?.id);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePickupMatchDto) {
    return this.pickupMatchesService.create(user.id, dto);
  }

  @Post(':id/join')
  @UseGuards(JwtAuthGuard)
  join(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: JoinPickupMatchDto,
  ) {
    return this.pickupMatchesService.join(id, user.id, { code: dto.code });
  }

  @Post(':id/leave')
  @UseGuards(JwtAuthGuard)
  leave(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.pickupMatchesService.leave(id, user.id);
  }

  @Patch(':id/score')
  @UseGuards(JwtAuthGuard)
  score(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: ScorePickupMatchDto,
  ) {
    return this.pickupMatchesService.score(id, user.id, dto);
  }

  @Post(':id/cancel')
  @UseGuards(JwtAuthGuard)
  cancel(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.pickupMatchesService.cancel(id, user.id);
  }
}
