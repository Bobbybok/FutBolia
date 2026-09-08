import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'pg';
import {
  postgresSslOption,
  resolveDatabaseConfig,
} from '../../config/database-config';

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
      const db = resolveDatabaseConfig(this.config);
      const ssl = postgresSslOption(db.ssl);
      const client = new Client({
        host: db.host,
        port: db.port,
        user: db.username,
        password: db.password,
        database: db.database,
        ssl: ssl || undefined,
        connectionTimeoutMillis: 5000,
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
