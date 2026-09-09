# Matchs simples (pickup)

Matchs amicaux hors tournoi : pas de classement, équipes A/B attribuées à l’inscription.

## Endpoints

- `GET /api/v1/pickup-matches` — matchs publics ouverts / complets
- `GET /api/v1/pickup-matches?mine=true` — mes matchs (JWT)
- `GET /api/v1/pickup-matches/:id` — détail + membres (code visible uniquement à l’hôte)
- `POST /api/v1/pickup-matches` — créer (JWT + e-mail vérifié)
- `POST /api/v1/pickup-matches/:id/join` — public seulement (privé → invitation)
- `POST /api/v1/pickup-matches/:id/leave` — quitter (pas l’hôte)
- `PATCH /api/v1/pickup-matches/:id/score` — hôte uniquement `{ homeScore, awayScore }`
- `POST /api/v1/pickup-matches/:id/cancel` — hôte

Privé : invitations amis (voir [invites.md](./invites.md)).

## Règles

- Capacité : `2 × playersPerTeam`
- Création : l’hôte est inscrit automatiquement côté **home** (équipe A)
- Inscription : remplissage A puis B selon l’ordre d’arrivée
- Statuts : `open` → `full` → `finished` / `cancelled`
- Privé : code généré à la création ; requis pour rejoindre
- Score : seul l’hôte saisit → statut `finished`
- L’hôte ne peut pas quitter : il doit annuler le match
