import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FriendsModule } from '../friends/friends.module';
import { TournamentsModule } from '../tournaments/tournaments.module';
import { PickupMatchesModule } from '../pickup-matches/pickup-matches.module';
import { InvitesController } from './invites.controller';
import { InvitesService } from './invites.service';

@Module({
  imports: [
    AuthModule,
    FriendsModule,
    forwardRef(() => TournamentsModule),
    forwardRef(() => PickupMatchesModule),
  ],
  controllers: [InvitesController],
  providers: [InvitesService],
  exports: [InvitesService],
})
export class InvitesModule {}
