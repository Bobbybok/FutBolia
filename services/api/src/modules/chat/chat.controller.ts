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
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { PostChatMessageDto } from './dto/post-chat-message.dto';

@Controller()
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

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
}
