import { Body, Controller, Delete, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { DeviceTokensService } from './device-tokens.service';
import {
  DeleteDeviceTokenDto,
  UpsertDeviceTokenDto,
} from './dto/device-token.dto';

@Controller('users/me')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly deviceTokens: DeviceTokensService) {}

  @Post('device-token')
  upsert(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpsertDeviceTokenDto,
  ) {
    return this.deviceTokens.upsert(user.id, dto.token.trim(), dto.platform);
  }

  @Delete('device-token')
  remove(
    @CurrentUser() user: AuthUser,
    @Body() dto: DeleteDeviceTokenDto,
  ) {
    return this.deviceTokens.remove(user.id, dto.token.trim());
  }
}
