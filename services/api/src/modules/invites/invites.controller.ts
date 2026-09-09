import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { EventInviteTargetType } from '../../common/enums';
import { InvitesService } from './invites.service';
import { CreateEventInvitesDto } from './dto/create-event-invites.dto';

@Controller('invites')
@UseGuards(JwtAuthGuard)
export class InvitesController {
  constructor(private readonly invites: InvitesService) {}

  @Get()
  listIncoming(@CurrentUser() user: AuthUser) {
    return this.invites.listIncoming(user.id);
  }

  @Get('outgoing')
  listOutgoing(
    @CurrentUser() user: AuthUser,
    @Query('targetType') targetType: EventInviteTargetType,
    @Query('targetId') targetId: string,
  ) {
    return this.invites.listOutgoingForTarget(user.id, targetType, targetId);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateEventInvitesDto) {
    return this.invites.create(user.id, dto);
  }

  @Post(':id/accept')
  accept(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.invites.accept(id, user.id);
  }

  @Post(':id/decline')
  decline(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.invites.decline(id, user.id);
  }

  @Post(':id/cancel')
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.invites.cancel(id, user.id);
  }
}
