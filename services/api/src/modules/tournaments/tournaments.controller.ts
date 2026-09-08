import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { TournamentsService } from './tournaments.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { UpdateTournamentDto } from './dto/update-tournament.dto';
import { JoinTournamentDto } from './dto/join-tournament.dto';

@Controller('tournaments')
export class TournamentsController {
  constructor(private readonly tournamentsService: TournamentsService) {}

  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  list(
    @Query('q') q: string | undefined,
    @Query('mine') mine: string | undefined,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.tournamentsService.list({
      q,
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
    return this.tournamentsService.getById(id, user?.id);
  }

  @Get(':id/members')
  @UseGuards(OptionalJwtAuthGuard)
  listMembers(
    @Param('id') id: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.tournamentsService.listMembers(id, user?.id);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTournamentDto) {
    return this.tournamentsService.create(user.id, dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  update(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateTournamentDto,
  ) {
    return this.tournamentsService.update(id, user.id, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  remove(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.tournamentsService.remove(id, user.id);
  }

  @Post(':id/join')
  @UseGuards(JwtAuthGuard)
  join(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: JoinTournamentDto,
  ) {
    return this.tournamentsService.join(id, user.id, dto.code);
  }

  @Post(':id/join-code/regenerate')
  @UseGuards(JwtAuthGuard)
  regenerateCode(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.tournamentsService.regenerateJoinCode(id, user.id);
  }
}
