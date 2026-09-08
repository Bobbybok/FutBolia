# Phase 9 — Chat par tournoi

## Règles

- Réservé aux **participants** du tournoi
- Envoyer : tout membre
- Supprimer : **auteur** ou **organisateur** (soft-delete)
- Corps max **1000** caractères
- Temps réel V1 : **polling** côté app (~4 s). Socket.io / push → phases suivantes

## API

- `GET /tournaments/:id/chat?before=&limit=`
- `POST /tournaments/:id/chat` `{ body }`
- `DELETE /chat/messages/:id`
