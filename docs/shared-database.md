# Base de données partagée (DEV)

Projet Neon : `morning-bird-81257321` (branch `production`)

## Chez toi (déjà fait)

- CLI Neon installée et liée au repo (`.neon`, gitignored)
- Variables dans `.env.local` (gitignored)
- `services/api/.env` pointe vers Neon (`DATABASE_SSL=true`)

## Chez ton ami

1. Installer la CLI : `npm i -g neon@latest`
2. `neon login`
3. Dans le clone FutBolia :
   ```bash
   neon link --project-id morning-bird-81257321 --branch production -y
   ```
4. Copier `DATABASE_URL_UNPOOLED` de `.env.local` vers `services/api/.env`  
   (ou récupérer la connection string dans la console Neon)
5. Mettre `DATABASE_SSL=true`
6. `npm run start:dev` dans `services/api`

Plus besoin de `docker compose up` pour Postgres.

## Fichiers

| Fichier | Commit ? |
|---------|----------|
| `neon.ts` | oui |
| `.env.local` | **non** |
| `.neon/` | **non** |
| `services/api/.env` | **non** |
