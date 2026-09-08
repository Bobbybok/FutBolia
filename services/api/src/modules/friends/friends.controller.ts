import {
  Body,
  Controller,
  Delete,
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
import { FriendsService } from './friends.service';
import { SendFriendRequestDto } from './dto/friends.dto';

@Controller('friends')
@UseGuards(JwtAuthGuard)
export class FriendsController {
  constructor(private readonly friends: FriendsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.friends.listFriends(user.id);
  }

  @Get('requests')
  requests(@CurrentUser() user: AuthUser) {
    return this.friends.listRequests(user.id);
  }

  @Get('search')
  search(@CurrentUser() user: AuthUser, @Query('q') q?: string) {
    return this.friends.search(user.id, q);
  }

  @Post('requests')
  send(@CurrentUser() user: AuthUser, @Body() dto: SendFriendRequestDto) {
    return this.friends.sendRequest(user.id, dto);
  }

  @Post('requests/:id/accept')
  accept(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.friends.accept(user.id, id);
  }

  @Post('requests/:id/decline')
  decline(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.friends.decline(user.id, id);
  }

  @Delete(':userId')
  unfriend(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.friends.unfriend(user.id, userId);
  }
}
