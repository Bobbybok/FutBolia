import { Global, Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { EventsGateway } from './gateways/events.gateway';
import { ConnectionRegistryService } from './services/connection-registry.service';
import { RealtimeDispatchService } from './services/realtime-dispatch.service';

@Global()
@Module({
  imports: [AuthModule, NotificationsModule],
  providers: [EventsGateway, ConnectionRegistryService, RealtimeDispatchService],
  exports: [ConnectionRegistryService, RealtimeDispatchService],
})
export class RealtimeModule {}
