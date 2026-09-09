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
}
