type EnvInput = Record<string, unknown>;

/**
 * Validate critical keys without dropping the rest of process.env.
 * Nest ConfigModule replaces config with the returned object.
 */
export function validateEnv(config: EnvInput): Record<string, unknown> {
  const port = Number(config.PORT ?? 3000);
  if (!Number.isFinite(port) || port <= 0) {
    throw new Error('PORT must be a positive number');
  }

  return {
    ...config,
    NODE_ENV: String(config.NODE_ENV ?? 'development'),
    PORT: port,
    API_PREFIX: String(config.API_PREFIX ?? 'api/v1'),
    DATABASE_ENABLED: String(config.DATABASE_ENABLED ?? 'true'),
    THROTTLE_TTL_MS: Number(config.THROTTLE_TTL_MS ?? 60_000),
    THROTTLE_LIMIT: Number(config.THROTTLE_LIMIT ?? 100),
  };
}
