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
  await ds.query(`
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS positions jsonb DEFAULT '[]'::jsonb
  `);
  await ds.query(`
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS height_cm smallint
  `);
  await ds.query(`
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS weight_kg smallint
  `);
  await ds.query(`
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS experience_level varchar(24)
  `);
  await ds.query(`
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS playing_since_year smallint
  `);
  await ds.query(`
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS availability jsonb DEFAULT '[]'::jsonb
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS profile_avatars (
      user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      mime_type varchar(64) NOT NULL,
      data bytea NOT NULL,
      updated_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS profile_hidden_items (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      item_type varchar(24) NOT NULL,
      item_id uuid NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (user_id, item_type, item_id)
    )
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS profile_hidden_items_user_id_idx
      ON profile_hidden_items (user_id)
  `);
  await ds.query(`
    ALTER TABLE team_members
      ADD COLUMN IF NOT EXISTS position varchar(8)
  `);
  await ds.query(`
    DO $$ BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'teams'
      ) THEN
        ALTER TABLE teams ADD COLUMN IF NOT EXISTS selector_id uuid;
      END IF;
    END $$;
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS team_chat_messages (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      team_id uuid NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
      author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      body text NOT NULL,
      deleted_at timestamptz,
      deleted_by_id uuid,
      created_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS team_chat_messages_team_id_idx
      ON team_chat_messages (team_id)
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS team_chat_messages_author_id_idx
      ON team_chat_messages (author_id)
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS team_chat_receipts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      team_id uuid NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      last_read_at timestamptz,
      chat_cleared_at timestamptz,
      chat_hidden_at timestamptz,
      UNIQUE (team_id, user_id)
    )
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS team_chat_receipts_team_id_idx
      ON team_chat_receipts (team_id)
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS team_chat_receipts_user_id_idx
      ON team_chat_receipts (user_id)
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS inter_team_chat_messages (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
      author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      body text NOT NULL,
      deleted_at timestamptz,
      deleted_by_id uuid,
      created_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS inter_team_chat_messages_tournament_id_idx
      ON inter_team_chat_messages (tournament_id)
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS inter_team_chat_messages_author_id_idx
      ON inter_team_chat_messages (author_id)
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS inter_team_chat_receipts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      last_read_at timestamptz,
      chat_cleared_at timestamptz,
      chat_hidden_at timestamptz,
      UNIQUE (tournament_id, user_id)
    )
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS inter_team_chat_receipts_tournament_id_idx
      ON inter_team_chat_receipts (tournament_id)
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS inter_team_chat_receipts_user_id_idx
      ON inter_team_chat_receipts (user_id)
  `);
  await ds.query(`
    UPDATE tournaments
    SET substitutes_count = starters_count
    WHERE substitutes_count IS DISTINCT FROM starters_count
  `);
  await ds.query(`
    DO $$ BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pickup_match_members'
          AND column_name = 'side'
      ) THEN
        ALTER TABLE pickup_match_members ALTER COLUMN side DROP NOT NULL;
      END IF;
    END $$;
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS tournament_covers (
      tournament_id uuid PRIMARY KEY REFERENCES tournaments(id) ON DELETE CASCADE,
      mime_type varchar(64) NOT NULL,
      data bytea NOT NULL,
      updated_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS tournament_photos (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      tournament_id uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
      uploaded_by_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mime_type varchar(64) NOT NULL,
      data bytea NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await ds.query(`
    CREATE INDEX IF NOT EXISTS tournament_photos_tournament_id_idx
      ON tournament_photos (tournament_id)
  `);
}
