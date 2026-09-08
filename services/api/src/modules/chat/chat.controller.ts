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

  @Get('tournaments/:tournamentId/chat')
  @UseGuards(JwtAuthGuard)
  list(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
  ) {
    return this.chatService.list(tournamentId, user.id, {
      before,
      limit: limit ? Number(limit) : undefined,
    });
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
