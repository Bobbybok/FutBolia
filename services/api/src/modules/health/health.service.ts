import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'pg';

export type HealthStatus = {
  status: 'ok' | 'degraded';
  app: string;
  environment: string;
  timestamp: string;
  database: {
    enabled: boolean;
    connected: boolean;
  };
};

@Injectable()
export class HealthService {
  constructor(private readonly config: ConfigService) {}

  async getStatus(): Promise<HealthStatus> {
    const enabled =
      (this.config.get<string>('DATABASE_ENABLED') ?? 'true').toLowerCase() !==
      'false';

    let connected = false;
    if (enabled) {
      const client = new Client({
        host: this.config.get<string>('DATABASE_HOST', 'localhost'),
        port: this.config.get<number>('DATABASE_PORT', 5432),
        user: this.config.get<string>('DATABASE_USER', 'futbolia'),
        password: this.config.get<string>('DATABASE_PASSWORD'),
        database: this.config.get<string>('DATABASE_NAME', 'futbolia_dev'),
        ssl:
          this.config.get<string>('DATABASE_SSL') === 'true'
            ? { rejectUnauthorized: false }
            : undefined,
        connectionTimeoutMillis: 2000,
      });

      try {
        await client.connect();
        await client.query('SELECT 1');
        connected = true;
      } catch {
        connected = false;
      } finally {
        await client.end().catch(() => undefined);
      }
    }

    const status: HealthStatus['status'] =
      !enabled || connected ? 'ok' : 'degraded';

    return {
      status,
      app: this.config.get<string>('APP_NAME', 'FutBolia'),
      environment: this.config.get<string>('NODE_ENV', 'development'),
      timestamp: new Date().toISOString(),
      database: {
        enabled,
        connected,
      },
    };
  }
}
