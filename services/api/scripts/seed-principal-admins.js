const fs = require('fs');
const path = require('path');
const argon2 = require('argon2');
const { DataSource } = require('typeorm');
const { randomBytes } = require('crypto');

const apiRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(apiRoot, '..', '..');

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const out = {};
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 0) continue;
    let v = t.slice(i + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    out[t.slice(0, i).trim()] = v;
  }
  return out;
}

const env = {
  ...parseEnvFile(path.join(repoRoot, '.env.local')),
  ...parseEnvFile(path.join(apiRoot, '.env')),
};

function parsePostgresUrl(raw) {
  const parsed = new URL(raw.trim().replace(/^['"]|['"]$/g, ''));
  const database = decodeURIComponent(parsed.pathname.replace(/^\//, '')).split(
    '/',
  )[0];
  return {
    host: parsed.hostname,
    port: parsed.port ? Number(parsed.port) : 5432,
    username: decodeURIComponent(parsed.username),
    password: decodeURIComponent(parsed.password),
    database: database || 'neondb',
    ssl: parsed.hostname.includes('neon.tech') || parsed.searchParams.get('sslmode') === 'require',
  };
}

function resolveDb() {
  const url = (env.DATABASE_URL_UNPOOLED || env.DATABASE_URL || '').trim();
  if (url) {
    const fromUrl = parsePostgresUrl(url);
    if (fromUrl.host.includes('neon.tech')) fromUrl.ssl = true;
    return fromUrl;
  }
  return {
    host: env.DATABASE_HOST || 'localhost',
    port: Number(env.DATABASE_PORT || 5432),
    username: env.DATABASE_USER || 'futbolia',
    password: env.DATABASE_PASSWORD || '',
    database: env.DATABASE_NAME || 'futbolia_dev',
    ssl: env.DATABASE_SSL === 'true',
  };
}

function randomPassword() {
  return randomBytes(12).toString('base64url');
}

function adminSpec(index) {
  const email = (env[`PRINCIPAL_ADMIN_${index}_EMAIL`] || '').trim().toLowerCase();
  const pseudo = (env[`PRINCIPAL_ADMIN_${index}_PSEUDO`] || '').trim();
  let password = (env[`PRINCIPAL_ADMIN_${index}_PASSWORD`] || '').trim();
  const generated = !password;
  if (email && generated) password = randomPassword();
  return { email, pseudo, password, generated };
}

const PERMISSIONS = [
  'manage_users',
  'manage_tournaments',
  'moderate_content',
  'view_security',
  'view_stats',
  'manage_admins',
  'manage_moderators',
];

async function upsertAdmin(ds, spec) {
  if (!spec.email || !spec.pseudo || spec.password.length < 8) {
    throw new Error(
      `Admin incomplet : email + pseudo + mot de passe (>=8) requis (${spec.email || 'sans email'})`,
    );
  }

  const hash = await argon2.hash(spec.password);
  const existing = await ds.query('SELECT id FROM users WHERE email = $1', [
    spec.email,
  ]);

  let userId;
  if (existing[0]) {
    userId = existing[0].id;
    await ds.query(
      `UPDATE users
       SET password_hash = $2,
           global_role = 'admin',
           status = 'active',
           email_verified_at = COALESCE(email_verified_at, NOW()),
           deleted_at = NULL
       WHERE id = $1`,
      [userId, hash],
    );
  } else {
    const inserted = await ds.query(
      `INSERT INTO users (email, password_hash, email_verified_at, status, global_role)
       VALUES ($1, $2, NOW(), 'active', 'admin')
       RETURNING id`,
      [spec.email, hash],
    );
    userId = inserted[0].id;
  }

  const profile = await ds.query(
    'SELECT id, pseudo FROM profiles WHERE user_id = $1',
    [userId],
  );
  const taken = await ds.query(
    'SELECT user_id FROM profiles WHERE pseudo = $1 AND user_id <> $2',
    [spec.pseudo, userId],
  );
  const pseudo = taken[0]
    ? profile[0]?.pseudo || `${spec.pseudo}${userId.slice(0, 4)}`
    : spec.pseudo;

  if (profile[0]) {
    await ds.query('UPDATE profiles SET pseudo = $2 WHERE user_id = $1', [
      userId,
      pseudo,
    ]);
  } else {
    await ds.query('INSERT INTO profiles (user_id, pseudo) VALUES ($1, $2)', [
      userId,
      pseudo,
    ]);
  }

  await ds.query('DELETE FROM admin_permissions WHERE user_id = $1', [userId]);
  for (const permission of PERMISSIONS) {
    await ds.query(
      `INSERT INTO admin_permissions (user_id, permission, granted_by_id)
       VALUES ($1, $2, $1)`,
      [userId, permission],
    );
  }

  await ds.query(
    `UPDATE refresh_tokens SET revoked_at = NOW()
     WHERE user_id = $1 AND revoked_at IS NULL`,
    [userId],
  );

  return {
    email: spec.email,
    pseudo,
    generatedPassword: spec.generated ? spec.password : null,
  };
}

async function grantAdminToExistingPseudo(ds, pseudo) {
  const rows = await ds.query(
    `SELECT u.id, u.email, p.pseudo
     FROM users u
     JOIN profiles p ON p.user_id = u.id
     WHERE LOWER(p.pseudo) = LOWER($1) AND u.deleted_at IS NULL`,
    [pseudo],
  );
  if (!rows[0]) {
    console.log(`Aucun joueur « ${pseudo} » à promouvoir`);
    return;
  }
  for (const row of rows) {
    await ds.query(
      `UPDATE users
       SET global_role = 'admin',
           status = 'active',
           email_verified_at = COALESCE(email_verified_at, NOW())
       WHERE id = $1`,
      [row.id],
    );
    await ds.query('DELETE FROM admin_permissions WHERE user_id = $1', [row.id]);
    for (const permission of PERMISSIONS) {
      await ds.query(
        `INSERT INTO admin_permissions (user_id, permission, granted_by_id)
         VALUES ($1, $2, $1)`,
        [row.id, permission],
      );
    }
    await ds.query(
      `UPDATE refresh_tokens SET revoked_at = NOW()
       WHERE user_id = $1 AND revoked_at IS NULL`,
      [row.id],
    );
    console.log(
      `Promu admin (mot de passe inchangé) : ${row.email} (${row.pseudo})`,
    );
  }
}

async function main() {
  const a1 = adminSpec(1);
  const a2 = adminSpec(2);
  if (!a1.email || !a2.email) {
    console.error(
      'Renseigne PRINCIPAL_ADMIN_1_EMAIL / PRINCIPAL_ADMIN_2_EMAIL (et pseudo + mot de passe) dans services/api/.env',
    );
    process.exit(1);
  }

  const db = resolveDb();
  const ds = new DataSource({
    type: 'postgres',
    host: db.host,
    port: db.port,
    username: db.username,
    password: db.password,
    database: db.database,
    ssl: db.ssl ? { rejectUnauthorized: false } : false,
  });
  await ds.initialize();
  await ds.query(`
    CREATE TABLE IF NOT EXISTS admin_permissions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL,
      permission varchar(64) NOT NULL,
      granted_by_id uuid,
      granted_at timestamptz NOT NULL DEFAULT NOW(),
      UNIQUE (user_id, permission)
    )
  `);
  await ds.query(`
    CREATE TABLE IF NOT EXISTS audit_logs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      admin_id uuid NOT NULL,
      action varchar(80) NOT NULL,
      target_id uuid,
      metadata jsonb,
      created_at timestamptz NOT NULL DEFAULT NOW()
    )
  `);

  await ds.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      type varchar(32) NOT NULL,
      target_id uuid NOT NULL,
      reporter_id uuid NOT NULL,
      reason text NOT NULL,
      status varchar(32) NOT NULL DEFAULT 'open',
      created_at timestamptz NOT NULL DEFAULT NOW(),
      reviewed_by_id uuid,
      reviewed_at timestamptz
    )
  `);

  try {
    const first = await upsertAdmin(ds, {
      ...a1,
      pseudo: a1.pseudo || 'admin1',
    });
    const second = await upsertAdmin(ds, {
      ...a2,
      pseudo: a2.pseudo || 'admin2',
    });
    console.log('Comptes admin principaux prêts :');
    console.log(`- ${first.email} (${first.pseudo || a1.pseudo})`);
    if (first.generatedPassword) {
      console.log(`  mot de passe généré : ${first.generatedPassword}`);
    }
    console.log(`- ${second.email} (${second.pseudo || a2.pseudo})`);
    if (second.generatedPassword) {
      console.log(`  mot de passe généré : ${second.generatedPassword}`);
    }

    const promoteRaw =
      env.PROMOTE_ADMIN_PSEUDOS || env.PRINCIPAL_ADMIN_PROMOTE_PSEUDOS || 'Bobby';
    const promoteList = promoteRaw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    for (const pseudo of promoteList) {
      await grantAdminToExistingPseudo(ds, pseudo);
    }

    console.log('Reconnecte-toi dans l’app pour obtenir un JWT à jour.');
  } finally {
    await ds.destroy();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
