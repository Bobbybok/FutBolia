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
- Public : visible dans la recherche
- Privé : code généré, modifiable / désactivable
- Le code n’est renvoyé qu’à l’organisateur
