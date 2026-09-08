# Database notes — FutBolia

## DEV

- PostgreSQL 16 via `docker compose up -d` (racine du repo)
- Variables : `services/api/.env` (copier depuis `.env.example`)
- `DATABASE_ENABLED=false` autorise le démarrage API sans Postgres (smoke test Phase 1)

## ORM

- **Phase 1** : ping SQL via le driver `pg` dans `/health` uniquement
- **Phase 2+** : TypeORM (entities + migrations) pour users, auth, tournois, etc.

## PROD

- Instance PostgreSQL **séparée** de DEV
- `synchronize: false` + migrations uniquement
- SSL activé (`DATABASE_SSL=true`)
