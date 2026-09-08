import { Module } from '@nestjs/common';
import { TournamentsService } from './tournaments.service';
import { TournamentsController } from './tournaments.controller';
import { AuthModule } from '../auth/auth.module';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';

@Module({
  imports: [AuthModule],
  controllers: [TournamentsController],
  providers: [TournamentsService, OptionalJwtAuthGuard],
  exports: [TournamentsService],
})
export class TournamentsModule {}
