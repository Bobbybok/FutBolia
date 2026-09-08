import { Module } from '@nestjs/common';
import { TeamsService } from './teams.service';
import { TeamsController } from './teams.controller';
import { AuthModule } from '../auth/auth.module';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';

@Module({
  imports: [AuthModule],
  controllers: [TeamsController],
  providers: [TeamsService, OptionalJwtAuthGuard],
  exports: [TeamsService],
})
export class TeamsModule {}
