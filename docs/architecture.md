# Architecture FutBolia (Phase 0–1)

## Décision

- **Mobile** : Flutter (Android d’abord, iOS ensuite)
- **API** : NestJS + validation DTO + guards
- **DB** : PostgreSQL (transactions ACID pour le mercato)
- **ORM** : TypeORM à partir de la Phase 2 (entities / migrations)
- **Temps réel** : Socket.io (plus tard, scoped)
- **Push** : FCM
- **Stockage** : Cloudflare R2

## Flux

```
Flutter → HTTPS/WSS → NestJS → Services métier → PostgreSQL
                              ↘ R2 / FCM / SMTP
```

## Règle d’or

Le client n’est jamais une source de vérité pour scores, rôles, recrutement ou classements.
