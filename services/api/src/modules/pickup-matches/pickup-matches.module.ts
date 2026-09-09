import { Module } from '@nestjs/common';
import { PickupMatchesService } from './pickup-matches.service';
import { PickupMatchesController } from './pickup-matches.controller';
import { AuthModule } from '../auth/auth.module';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';

@Module({
  imports: [AuthModule],
  controllers: [PickupMatchesController],
  providers: [PickupMatchesService, OptionalJwtAuthGuard],
  exports: [PickupMatchesService],
})
export class PickupMatchesModule {}
