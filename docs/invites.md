# Invitations amis (tournois & matchs privés)

Les codes d’accès sont **retirés**. L’accès privé se fait uniquement par **invitation d’un ami**.

## Qui peut inviter ?

- **Tournoi privé** : organisateur
- **Match privé** : hôte (créateur)

L’invité doit être un **ami accepté**.

## API

- `POST /api/v1/invites` `{ targetType, targetId, friendIds[] }`
  - `targetType`: `tournament` | `pickup_match`
- `GET /api/v1/invites` — invitations reçues (pending)
- `POST /api/v1/invites/:id/accept` — rejoint l’événement
- `POST /api/v1/invites/:id/decline`
- `POST /api/v1/invites/:id/cancel` — expéditeur

Rejoindre un événement privé sans invitation → **403**.

## Mobile

- Détail tournoi / match privé : bouton **Inviter des amis**
- Onglet **Amis** : section invitations + bouton inviter sur chaque ami
