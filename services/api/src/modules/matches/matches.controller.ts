import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { MatchesService } from './matches.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';

@Controller()
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Get('tournaments/:tournamentId/matches')
  @UseGuards(JwtAuthGuard)
  list(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.matchesService.listByTournament(tournamentId, user.id);
  }

  @Get('tournaments/:tournamentId/standings')
  @UseGuards(JwtAuthGuard)
  standings(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.matchesService.standings(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/matches')
  @UseGuards(JwtAuthGuard)
  create(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateMatchDto,
  ) {
    return this.matchesService.create(tournamentId, user.id, dto);
  }

  @Post('tournaments/:tournamentId/matches/generate-round-robin')
  @UseGuards(JwtAuthGuard)
  generateRoundRobin(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.matchesService.generateRoundRobin(tournamentId, user.id);
  }

  @Get('matches/:id')
  @UseGuards(JwtAuthGuard)
  getOne(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.matchesService.getById(id, user.id);
  }

  @Patch('matches/:id')
  @UseGuards(JwtAuthGuard)
  update(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateMatchDto,
  ) {
    return this.matchesService.update(id, user.id, dto);
  }

  @Post('matches/:id/cancel')
  @UseGuards(JwtAuthGuard)
  cancel(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.matchesService.cancel(id, user.id);
  }

  @Delete('matches/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  remove(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.matchesService.remove(id, user.id);
  }
}
