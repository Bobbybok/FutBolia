import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import {
  postgresSslOption,
  resolveDatabaseConfig,
} from '../config/database-config';
import { ensureSchema } from './ensure-schema';
import { User } from '../modules/users/entities/user.entity';
import { Profile } from '../modules/users/entities/profile.entity';
import { RefreshToken } from '../modules/auth/entities/refresh-token.entity';
import { AuthToken } from '../modules/auth/entities/auth-token.entity';
import { Tournament } from '../modules/tournaments/entities/tournament.entity';
import { TournamentMember } from '../modules/tournaments/entities/tournament-member.entity';
import { Team } from '../modules/teams/entities/team.entity';
import { TeamMember } from '../modules/teams/entities/team-member.entity';
import { RecruitmentOffer } from '../modules/mercato/entities/recruitment-offer.entity';
import { Match } from '../modules/matches/entities/match.entity';
import { PickupMatch } from '../modules/pickup-matches/entities/pickup-match.entity';
import { PickupMatchMember } from '../modules/pickup-matches/entities/pickup-match-member.entity';
import { TournamentChatMessage } from '../modules/chat/entities/tournament-chat-message.entity';
import { ForumPost } from '../modules/forum/entities/forum-post.entity';
import { ForumReply } from '../modules/forum/entities/forum-reply.entity';
import { AdminPermission } from '../modules/admin/entities/admin-permission.entity';
import { AuditLog } from '../modules/admin/entities/audit-log.entity';
import { Report } from '../modules/admin/entities/report.entity';
import { FriendRequest } from '../modules/friends/entities/friend-request.entity';
import { Conversation } from '../modules/private-chat/entities/conversation.entity';
import { DirectMessage } from '../modules/private-chat/entities/direct-message.entity';
import { EventInvite } from '../modules/invites/entities/event-invite.entity';

export const TYPEORM_DATA_SOURCE = 'TYPEORM_DATA_SOURCE';

@Global()
@Module({
  providers: [
    {
      provide: TYPEORM_DATA_SOURCE,
      inject: [ConfigService],
      useFactory: async (config: ConfigService): Promise<DataSource | null> => {
        const enabled =
          (config.get<string>('DATABASE_ENABLED') ?? 'true').toLowerCase() !==
          'false';

        if (!enabled) {
          return null;
        }

        const db = resolveDatabaseConfig(config);

        const dataSource = new DataSource({
          type: 'postgres',
          host: db.host,
          port: db.port,
          username: db.username,
          password: db.password,
          database: db.database,
          ssl: postgresSslOption(db.ssl),
          entities: [
            User,
            Profile,
            RefreshToken,
            AuthToken,
            Tournament,
            TournamentMember,
            Team,
            TeamMember,
            RecruitmentOffer,
            Match,
            PickupMatch,
            PickupMatchMember,
            TournamentChatMessage,
            ForumPost,
            ForumReply,
            AdminPermission,
            AuditLog,
            Report,
            FriendRequest,
            Conversation,
            DirectMessage,
            EventInvite,
          ],
          synchronize: (() => {
            const explicit = config.get<string>('DATABASE_SYNC');
            if (explicit != null && explicit !== '') {
              return explicit.toLowerCase() === 'true';
            }
            // Default: sync in non-production (no migrations yet).
            return config.get<string>('NODE_ENV') !== 'production';
          })(),
          logging: config.get<string>('DATABASE_LOGGING') === 'true',
        });

        if (!dataSource.isInitialized) {
          await dataSource.initialize();
        }
        await ensureSchema(dataSource);

        return dataSource;
      },
    },
  ],
  exports: [TYPEORM_DATA_SOURCE],
})
export class DatabaseModule {}
