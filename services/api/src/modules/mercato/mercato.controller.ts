import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { MercatoService } from './mercato.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreateOfferDto } from './dto/create-offer.dto';
import { NominateSelectorDto } from '../tournaments/dto/nominate-selector.dto';
import { IsUUID } from 'class-validator';

class AssignSelectorDto {
  @IsUUID()
  selectorId!: string;
}

@Controller()
export class MercatoController {
  constructor(private readonly mercatoService: MercatoService) {}

  @Get('tournaments/:tournamentId/mercato')
  @UseGuards(JwtAuthGuard)
  board(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.mercatoService.getBoard(tournamentId, user.id);
  }

  @Get('mercato/offers/mine')
  @UseGuards(JwtAuthGuard)
  myOffers(
    @CurrentUser() user: AuthUser,
    @Query('tournamentId') tournamentId?: string,
  ) {
    return this.mercatoService.listMyOffers(user.id, tournamentId);
  }

  @Post('mercato/offers')
  @UseGuards(JwtAuthGuard)
  createOffer(@CurrentUser() user: AuthUser, @Body() dto: CreateOfferDto) {
    return this.mercatoService.createOffer(user.id, dto);
  }

  @Post('mercato/offers/:id/accept')
  @UseGuards(JwtAuthGuard)
  accept(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.mercatoService.acceptOffer(id, user.id);
  }

  @Post('mercato/offers/:id/reject')
  @UseGuards(JwtAuthGuard)
  reject(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.mercatoService.rejectOffer(id, user.id);
  }

  @Post('tournaments/:tournamentId/selectors')
  @UseGuards(JwtAuthGuard)
  nominate(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: NominateSelectorDto,
  ) {
    return this.mercatoService.nominateSelector(
      tournamentId,
      user.id,
      dto.userId,
    );
  }

  @Post('teams/:teamId/selector')
  @UseGuards(JwtAuthGuard)
  assignSelector(
    @Param('teamId') teamId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: AssignSelectorDto,
  ) {
    return this.mercatoService.assignSelectorToTeam(
      teamId,
      user.id,
      dto.selectorId,
    );
  }
}
