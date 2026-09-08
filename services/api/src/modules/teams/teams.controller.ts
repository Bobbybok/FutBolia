import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { TeamsService } from './teams.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreateTeamDto } from './dto/create-team.dto';
import { UpdateTeamDto } from './dto/update-team.dto';
import { AddTeamMemberDto } from './dto/add-team-member.dto';
import { UpdateTeamMemberDto } from './dto/update-team-member.dto';
import { SetCaptainDto } from './dto/set-captain.dto';

@Controller()
export class TeamsController {
  constructor(private readonly teamsService: TeamsService) {}

  @Get('tournaments/:tournamentId/teams')
  @UseGuards(OptionalJwtAuthGuard)
  list(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.teamsService.listByTournament(tournamentId, user?.id);
  }

  @Post('tournaments/:tournamentId/teams')
  @UseGuards(JwtAuthGuard)
  create(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateTeamDto,
  ) {
    return this.teamsService.create(tournamentId, user.id, dto);
  }

  @Get('teams/:id')
  @UseGuards(OptionalJwtAuthGuard)
  getOne(
    @Param('id') id: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.teamsService.getById(id, user?.id);
  }

  @Patch('teams/:id')
  @UseGuards(JwtAuthGuard)
  update(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateTeamDto,
  ) {
    return this.teamsService.update(id, user.id, dto);
  }

  @Post('teams/:id/members')
  @UseGuards(JwtAuthGuard)
  addMember(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: AddTeamMemberDto,
  ) {
    return this.teamsService.addMember(id, user.id, dto);
  }

  @Patch('teams/:id/members/:userId')
  @UseGuards(JwtAuthGuard)
  updateMember(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateTeamMemberDto,
  ) {
    return this.teamsService.updateMember(id, userId, user.id, dto);
  }

  @Delete('teams/:id/members/:userId')
  @UseGuards(JwtAuthGuard)
  removeMember(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.teamsService.removeMember(id, userId, user.id);
  }

  @Post('teams/:id/captain')
  @UseGuards(JwtAuthGuard)
  setCaptain(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: SetCaptainDto,
  ) {
    return this.teamsService.setCaptain(id, user.id, dto.userId);
  }

  @Post('teams/:id/leave')
  @UseGuards(JwtAuthGuard)
  leave(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.teamsService.leave(id, user.id);
  }

  @Post('teams/:id/validate')
  @UseGuards(JwtAuthGuard)
  validate(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.teamsService.validateTeam(id, user.id);
  }

  @Post('teams/:id/unvalidate')
  @UseGuards(JwtAuthGuard)
  unvalidate(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.teamsService.unvalidateTeam(id, user.id);
  }
}
