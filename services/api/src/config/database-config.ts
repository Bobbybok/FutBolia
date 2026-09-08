export type DatabaseConnectionConfig = {
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
  ssl: boolean;
};

type EnvReader = {
  get: (key: string, defaultValue?: string) => string | undefined;
};

function stripQuotes(value: string): string {
  return value.trim().replace(/^['"]|['"]$/g, '');
}

export function parsePostgresUrl(raw: string): DatabaseConnectionConfig {
  const parsed = new URL(stripQuotes(raw));
  const database = decodeURIComponent(parsed.pathname.replace(/^\//, '')).split(
    '/',
  )[0];
  const sslMode = parsed.searchParams.get('sslmode');
  const neonHost = parsed.hostname.includes('neon.tech');
  const ssl =
    neonHost ||
    sslMode === 'require' ||
    sslMode === 'verify-ca' ||
    sslMode === 'verify-full';

  return {
    host: parsed.hostname,
    port: parsed.port ? Number(parsed.port) : 5432,
    username: decodeURIComponent(parsed.username),
    password: decodeURIComponent(parsed.password),
    database: database || 'neondb',
    ssl,
  };
}

export function resolveDatabaseConfig(
  config: EnvReader,
): DatabaseConnectionConfig {
  const unpooled = config.get('DATABASE_URL_UNPOOLED')?.trim();
  const pooled = config.get('DATABASE_URL')?.trim();
  const url = unpooled || pooled;

  if (url) {
    const fromUrl = parsePostgresUrl(url);
    if (fromUrl.host.includes('neon.tech')) {
      fromUrl.ssl = true;
    } else if (config.get('DATABASE_SSL') === 'true') {
      fromUrl.ssl = true;
    } else if (config.get('DATABASE_SSL') === 'false') {
      fromUrl.ssl = false;
    }
    return fromUrl;
  }

  return {
    host: config.get('DATABASE_HOST', 'localhost') ?? 'localhost',
    port: Number(config.get('DATABASE_PORT') ?? 5432),
    username: config.get('DATABASE_USER', 'futbolia') ?? 'futbolia',
    password: config.get('DATABASE_PASSWORD') ?? '',
    database: config.get('DATABASE_NAME', 'futbolia_dev') ?? 'futbolia_dev',
    ssl: config.get('DATABASE_SSL') === 'true',
  };
}

export function postgresSslOption(ssl: boolean) {
  return ssl ? { rejectUnauthorized: false } : false;
}
