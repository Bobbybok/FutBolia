import { Global, Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Global()
@Module({
  imports: [AuthModule],
  controllers: [NotificationsController],
  providers: [DeviceTokensService, NotificationsService],
  exports: [DeviceTokensService, NotificationsService],
})
export class NotificationsModule {}
