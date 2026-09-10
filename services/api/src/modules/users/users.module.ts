import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { CareerService } from './career.service';
import { AuthModule } from '../auth/auth.module';
import { FriendsModule } from '../friends/friends.module';

@Module({
  imports: [AuthModule, FriendsModule],
  controllers: [UsersController],
  providers: [UsersService, CareerService],
  exports: [UsersService],
})
export class UsersModule {}
