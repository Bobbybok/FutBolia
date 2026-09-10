import { Global, Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { EventsGateway } from './gateways/events.gateway';
import { ConnectionRegistryService } from './services/connection-registry.service';
import { LiveEventsService } from './services/live-events.service';
import { RealtimeDispatchService } from './services/realtime-dispatch.service';

@Global()
@Module({
  imports: [AuthModule, NotificationsModule],
  providers: [
    EventsGateway,
    ConnectionRegistryService,
    RealtimeDispatchService,
    LiveEventsService,
  ],
  exports: [
    ConnectionRegistryService,
    RealtimeDispatchService,
    LiveEventsService,
  ],
})
export class RealtimeModule {}
