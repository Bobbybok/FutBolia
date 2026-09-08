import {
  parsePostgresUrl,
  resolveDatabaseConfig,
} from './database-config';

describe('database-config', () => {
  it('parses a Neon unpooled URL', () => {
    const parsed = parsePostgresUrl(
      'postgresql://neondb_owner:s3cret@ep-example.c-2.eu-west-2.aws.neon.tech/neondb?channel_binding=require&sslmode=require',
    );

    expect(parsed).toEqual({
      host: 'ep-example.c-2.eu-west-2.aws.neon.tech',
      port: 5432,
      username: 'neondb_owner',
      password: 's3cret',
      database: 'neondb',
      ssl: true,
    });
  });

  it('prefers DATABASE_URL_UNPOOLED over discrete vars', () => {
    const resolved = resolveDatabaseConfig({
      get: (key: string, fallback?: string) => {
        const map: Record<string, string> = {
          DATABASE_URL_UNPOOLED:
            'postgresql://owner:pw@ep-db.neon.tech/neondb?sslmode=require',
          DATABASE_HOST: 'localhost',
          DATABASE_USER: 'futbolia',
          DATABASE_SSL: 'true',
        };
        return map[key] ?? fallback;
      },
    });

    expect(resolved.host).toBe('ep-db.neon.tech');
    expect(resolved.username).toBe('owner');
    expect(resolved.ssl).toBe(true);
  });

  it('falls back to discrete vars without a URL', () => {
    const resolved = resolveDatabaseConfig({
      get: (key: string, fallback?: string) => {
        const map: Record<string, string> = {
          DATABASE_HOST: 'localhost',
          DATABASE_PORT: '5432',
          DATABASE_USER: 'futbolia',
          DATABASE_PASSWORD: 'local',
          DATABASE_NAME: 'futbolia_dev',
          DATABASE_SSL: 'false',
        };
        return map[key] ?? fallback;
      },
    });

    expect(resolved).toEqual({
      host: 'localhost',
      port: 5432,
      username: 'futbolia',
      password: 'local',
      database: 'futbolia_dev',
      ssl: false,
    });
  });
});
