import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FriendsModule } from '../friends/friends.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';

@Module({
  imports: [AuthModule, FriendsModule],
  controllers: [ConversationsController],
  providers: [ConversationsService],
})
export class PrivateChatModule {}
