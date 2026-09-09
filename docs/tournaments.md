# Phase 3 — Tournois

## Endpoints

- `GET /api/v1/tournaments?q=&mine=true`
- `GET /api/v1/tournaments/:id`
- `GET /api/v1/tournaments/:id/members`
- `POST /api/v1/tournaments` (JWT + e-mail vérifié)
- `PATCH /api/v1/tournaments/:id` (organisateur)
- `POST /api/v1/tournaments/:id/join` (JWT + e-mail vérifié, code si privé)
- `POST /api/v1/tournaments/:id/join-code/regenerate` (organisateur)

## Règles

- Création / inscription : e-mail vérifié obligatoire
- Public : visible dans la recherche, rejoindre librement
- Privé : accès uniquement par **invitation d’ami** (organisateur) — plus de code
