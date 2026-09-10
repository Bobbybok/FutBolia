import { Module } from '@nestjs/common';
import { ChatService } from './chat.service';
import { TeamChatService } from './team-chat.service';
import { InterTeamChatService } from './inter-team-chat.service';
import { ChatController } from './chat.controller';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [ChatController],
  providers: [ChatService, TeamChatService, InterTeamChatService],
  exports: [ChatService, TeamChatService, InterTeamChatService],
})
export class ChatModule {}
