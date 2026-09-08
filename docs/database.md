# Database notes — FutBolia

## DEV

- **Docker local** : `docker compose up -d` (racine du repo) + variables discrètes dans `services/api/.env`
- **Neon** : `neon link` écrit `.env.local` à la racine. L’API lit `DATABASE_URL_UNPOOLED` (prioritaire) puis `DATABASE_URL`, sinon `DATABASE_HOST` / `USER` / `PASSWORD` / `NAME`
- `DATABASE_SSL=true` obligatoire pour Neon
- `DATABASE_ENABLED=false` autorise le démarrage API sans Postgres (smoke test Phase 1)
- Chaque poste Docker a sa propre base. Une base Neon partagée est commune à tous ceux qui s’y connectent.

## ORM

- **Phase 1** : ping SQL via le driver `pg` dans `/health` uniquement
- **Phase 2+** : TypeORM (entities + migrations) pour users, auth, tournois, etc.

## PROD

- Instance PostgreSQL **séparée** de DEV
- `synchronize: false` + migrations uniquement
- SSL activé (`DATABASE_SSL=true`)
