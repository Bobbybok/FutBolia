import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { TeamChatService } from './team-chat.service';
import { InterTeamChatService } from './inter-team-chat.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { PostChatMessageDto } from './dto/post-chat-message.dto';

@Controller()
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly teamChat: TeamChatService,
    private readonly interTeamChat: InterTeamChatService,
  ) {}

  @Get('chat/inbox')
  @UseGuards(JwtAuthGuard)
  inbox(@CurrentUser() user: AuthUser) {
    return this.chatService.inbox(user.id);
  }

  @Get('chat/unread-count')
  @UseGuards(JwtAuthGuard)
  unreadCount(@CurrentUser() user: AuthUser) {
    return this.chatService.unreadCount(user.id);
  }

  @Get('tournaments/:tournamentId/chat')
  @UseGuards(JwtAuthGuard)
  list(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
    @Query('restoreInbox') restoreInbox?: string,
  ) {
    return this.chatService.list(tournamentId, user.id, {
      before,
      limit: limit ? Number(limit) : undefined,
      restoreInbox: restoreInbox === '1' || restoreInbox === 'true',
    });
  }

  @Post('tournaments/:tournamentId/chat/clear')
  @UseGuards(JwtAuthGuard)
  clearMine(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.chatService.clearForMe(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/chat/clear-all')
  @UseGuards(JwtAuthGuard)
  clearAll(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.chatService.clearForEveryone(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/chat/hide')
  @UseGuards(JwtAuthGuard)
  hide(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.chatService.hideForMe(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/chat')
  @UseGuards(JwtAuthGuard)
  post(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: PostChatMessageDto,
  ) {
    return this.chatService.post(tournamentId, user.id, dto);
  }

  @Delete('chat/messages/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  remove(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.chatService.remove(id, user.id);
  }

  @Get('teams/:teamId/chat')
  @UseGuards(JwtAuthGuard)
  listTeam(
    @Param('teamId') teamId: string,
    @CurrentUser() user: AuthUser,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
    @Query('restoreInbox') restoreInbox?: string,
  ) {
    return this.teamChat.list(teamId, user.id, {
      before,
      limit: limit ? Number(limit) : undefined,
      restoreInbox: restoreInbox === '1' || restoreInbox === 'true',
    });
  }

  @Post('teams/:teamId/chat')
  @UseGuards(JwtAuthGuard)
  postTeam(
    @Param('teamId') teamId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: PostChatMessageDto,
  ) {
    return this.teamChat.post(teamId, user.id, dto);
  }

  @Post('teams/:teamId/chat/clear')
  @UseGuards(JwtAuthGuard)
  clearTeamMine(
    @Param('teamId') teamId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.teamChat.clearForMe(teamId, user.id);
  }

  @Post('teams/:teamId/chat/clear-all')
  @UseGuards(JwtAuthGuard)
  clearTeamAll(
    @Param('teamId') teamId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.teamChat.clearForEveryone(teamId, user.id);
  }

  @Post('teams/:teamId/chat/hide')
  @UseGuards(JwtAuthGuard)
  hideTeam(
    @Param('teamId') teamId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.teamChat.hideForMe(teamId, user.id);
  }

  @Delete('chat/team-messages/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  removeTeamMessage(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.teamChat.remove(id, user.id);
  }

  @Get('tournaments/:tournamentId/inter-team-chat')
  @UseGuards(JwtAuthGuard)
  listInterTeam(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
    @Query('restoreInbox') restoreInbox?: string,
  ) {
    return this.interTeamChat.list(tournamentId, user.id, {
      before,
      limit: limit ? Number(limit) : undefined,
      restoreInbox: restoreInbox === '1' || restoreInbox === 'true',
    });
  }

  @Post('tournaments/:tournamentId/inter-team-chat')
  @UseGuards(JwtAuthGuard)
  postInterTeam(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: PostChatMessageDto,
  ) {
    return this.interTeamChat.post(tournamentId, user.id, dto);
  }

  @Post('tournaments/:tournamentId/inter-team-chat/clear')
  @UseGuards(JwtAuthGuard)
  clearInterTeamMine(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.interTeamChat.clearForMe(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/inter-team-chat/clear-all')
  @UseGuards(JwtAuthGuard)
  clearInterTeamAll(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.interTeamChat.clearForEveryone(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/inter-team-chat/hide')
  @UseGuards(JwtAuthGuard)
  hideInterTeam(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.interTeamChat.hideForMe(tournamentId, user.id);
  }

  @Delete('chat/inter-team-messages/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  removeInterTeamMessage(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.interTeamChat.remove(id, user.id);
  }
}
