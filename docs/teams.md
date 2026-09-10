# Phase 4 — Équipes

## Endpoints

- `GET /api/v1/tournaments/:tournamentId/teams`
- `POST /api/v1/tournaments/:tournamentId/teams`
- `GET /api/v1/teams/:id`
- `PATCH /api/v1/teams/:id`
- `POST /api/v1/teams/:id/members`
- `PATCH /api/v1/teams/:id/members/:userId`
- `DELETE /api/v1/teams/:id/members/:userId`
- `POST /api/v1/teams/:id/captain`

## Règles serveur

- Un joueur = une seule équipe par tournoi
- Limites titulaires / remplaçants selon le tournoi
- Seuls organisateur ou capitaine gèrent l’effectif
- Le créateur devient capitaine + titulaire
- Impossible de retirer le capitaine sans transfert préalable
- Chaque mutation (créer / modifier / supprimer une équipe, effectif, capitaine) émet `tournament:updated` en Socket.io : les apps reconnectées rechargent sans pull-to-refresh
