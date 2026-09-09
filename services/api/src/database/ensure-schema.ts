import { DataSource } from 'typeorm';

/**
 * TypeORM synchronize does not always ALTER existing Neon tables.
 * Apply additive patches on every boot so local/prod stay queryable.
 */
export async function ensureSchema(ds: DataSource): Promise<void> {
  await ds.query(`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS suspended_until timestamptz
  `);
  await ds.query(`
    ALTER TABLE reports
      ADD COLUMN IF NOT EXISTS reason_code varchar(32)
  `);
  await ds.query(`
    ALTER TABLE reports
      ADD COLUMN IF NOT EXISTS comment text
  `);
  await ds.query(`
    ALTER TABLE tournament_members
      ADD COLUMN IF NOT EXISTS last_read_at timestamptz
  `);
  await ds.query(`
    ALTER TABLE tournament_members
      ADD COLUMN IF NOT EXISTS chat_cleared_at timestamptz
  `);
  await ds.query(`
    ALTER TABLE tournament_members
      ADD COLUMN IF NOT EXISTS chat_hidden_at timestamptz
  `);
  await ds.query(`
    ALTER TABLE conversations
      ADD COLUMN IF NOT EXISTS user1_cleared_at timestamptz
  `);
  await ds.query(`
    ALTER TABLE conversations
      ADD COLUMN IF NOT EXISTS user2_cleared_at timestamptz
  `);
  await ds.query(`
    ALTER TABLE conversations
      ADD COLUMN IF NOT EXISTS user1_hidden_at timestamptz
  `);
  await ds.query(`
    ALTER TABLE conversations
      ADD COLUMN IF NOT EXISTS user2_hidden_at timestamptz
  `);
  await ds.query(`
    DO $$ BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'device_tokens'
      ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS device_tokens_token_key
          ON device_tokens (token);
        CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx
          ON device_tokens (user_id);
      END IF;
    END $$;
  `);
}
