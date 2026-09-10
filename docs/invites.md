# Invitations (tournois & matchs)

Les codes d’accès sont **retirés**. Un événement **privé** se rejoint uniquement par **invitation**.

## Qui peut inviter ?

- **Tournoi** : organisateur (ou staff `manage_tournaments`)
- **Match** : hôte (ou staff)

L’invité peut être **n’importe quel joueur**, trouvé par **pseudo**. Plus besoin d’être ami.

## API

- `POST /api/v1/invites` `{ targetType, targetId, userIds?, friendIds?, pseudos? }`
  - `targetType`: `tournament` | `pickup_match`
  - `friendIds` : alias de `userIds` (compat)
  - `pseudos` : invitation par pseudo exact (insensible à la casse)
- `GET /api/v1/friends/search?q=` — recherche de joueurs (min. 2 caractères)
- `GET /api/v1/invites` — invitations reçues (pending)
- `POST /api/v1/invites/:id/accept` — rejoint l’événement
- `POST /api/v1/invites/:id/decline`
- `POST /api/v1/invites/:id/cancel` — expéditeur

Rejoindre un événement privé sans invitation → **403**.

## Mobile

- Détail tournoi / match : bouton **Inviter un joueur** (recherche par pseudo)
- Onglet **Amis** : invitations reçues + inviter un ami vers un événement privé
