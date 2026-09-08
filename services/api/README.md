# API NestJS — FutBolia

Voir le [README racine](../../README.md) pour l’installation globale.

```bat
copy ..\..\.env.example .env
npm install
npm run start:dev
```

Health : `GET /api/v1/health`

Neon : l’API accepte `DATABASE_URL_UNPOOLED` (prioritaire) ou `DATABASE_URL`. `.env.local` à la racine du repo est chargé automatiquement.
