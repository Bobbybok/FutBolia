# Phase 3 — Tournois

## Endpoints

- `GET /api/v1/tournaments?q=&mine=true`
- `GET /api/v1/tournaments/:id`
- `GET /api/v1/tournaments/:id/members`
- `POST /api/v1/tournaments` (JWT + e-mail vérifié)
- `PATCH /api/v1/tournaments/:id` (organisateur)
- `POST /api/v1/tournaments/:id/join` (JWT + e-mail vérifié, code si privé)
- `POST /api/v1/tournaments/:id/join-code/regenerate` (organisateur)

- `GET /api/v1/tournaments/:id/cover` — image du tournoi (publique)
- `POST /api/v1/tournaments/:id/cover` — orga ou admin `manage_tournaments`
- `DELETE /api/v1/tournaments/:id/cover` — orga ou admin
- `GET /api/v1/tournaments/:id/photos` — métadonnées album
- `POST /api/v1/tournaments/:id/photos` — orga, capitaine d’une équipe, ou admin
- `GET /api/v1/tournaments/:id/photos/:photoId` — fichier
- `DELETE /api/v1/tournaments/:id/photos/:photoId` — orga ou admin

## Règles

- Création / inscription : e-mail vérifié obligatoire
- Public : visible dans la recherche, rejoindre librement
- Privé : accès uniquement par **invitation d’ami** (organisateur) — plus de code
- Mutations (créer / modifier / supprimer, rejoindre / quitter) : événement Socket.io `tournament:updated` + `lobby:changed` pour les listes
- Photo du tournoi : JPEG / PNG / WebP, 1,5 Mo max, stockée en Postgres (`tournament_covers`)
- Album : 24 photos max. Orga et admin (`manage_tournaments`) ajoutent / suppriment. Les **capitaines** peuvent seulement ajouter. Visible sur la fiche tournoi.
