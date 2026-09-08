import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
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
import { TournamentChatMessage } from '../modules/chat/entities/tournament-chat-message.entity';
import { ForumPost } from '../modules/forum/entities/forum-post.entity';
import { ForumReply } from '../modules/forum/entities/forum-reply.entity';

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

        const databaseUrl = config.get<string>('DATABASE_URL');
        const useSsl =
          config.get<string>('DATABASE_SSL') === 'true' ||
          Boolean(databaseUrl && /sslmode=require/i.test(databaseUrl));

        const dataSource = new DataSource({
          type: 'postgres',
          ...(databaseUrl
            ? {
                url: databaseUrl,
              }
            : {
                host: config.get<string>('DATABASE_HOST', 'localhost'),
                port: Number(config.get('DATABASE_PORT') ?? 5432),
                username: config.get<string>('DATABASE_USER', 'futbolia'),
                password: config.get<string>('DATABASE_PASSWORD'),
                database: config.get<string>('DATABASE_NAME', 'futbolia_dev'),
              }),
          ssl: useSsl ? { rejectUnauthorized: false } : false,
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
            TournamentChatMessage,
            ForumPost,
            ForumReply,
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

        return dataSource;
      },
    },
  ],
  exports: [TYPEORM_DATA_SOURCE],
})
export class DatabaseModule {}
