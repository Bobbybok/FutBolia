# Phase 9 — Chat par tournoi

## Règles

- Un **chat privé** existe pour **chaque** tournoi (public ou privé)
- Réservé aux **participants** du tournoi (modo / admin peuvent **lire** et **supprimer** sans être inscrits)
- Visible dans l’onglet **Messages** tant que tu es membre
- **Supprimer la conversation** : retire le fil de Messages (pour toi). Pour le retrouver : ouvrir le chat **une fois** depuis la fiche **Tournoi** (un nouveau message ne le ramène pas)
- Envoyer : tout membre
- Supprimer un message **pour tout le monde** :
  - l’**auteur**
  - l’**organisateur** (chat du tournoi)
  - **modo / admin** (tous les chats : tournoi et DM)
- **Vider le chat** (pour soi) : Messages et chat du tournoi, y compris pour l’organisateur
- **Vider pour tout le monde** : **organisateur uniquement**, uniquement depuis la **fiche tournoi** (pas depuis Messages)
- Corps max **1000** caractères
- Temps réel V1 : **polling** côté app (~4 s). Socket.io / push → phases suivantes

## API

- `GET /chat/inbox` — fils des tournois dont tu es membre (hors fils masqués)
- `GET /chat/unread-count`
- `GET /tournaments/:id/chat?before=&limit=&restoreInbox=` — `restoreInbox=1` depuis la fiche tournoi (réaffiche le fil dans Messages)
- `POST /tournaments/:id/chat` `{ body }`
- `POST /tournaments/:id/chat/clear` — vider pour soi
- `POST /tournaments/:id/chat/clear-all` — organisateur, vider pour tous
- `POST /tournaments/:id/chat/hide` — retirer de Messages
- `DELETE /chat/messages/:id` — auteur, organisateur, ou staff
- `POST /conversations/:id/clear` — vider un DM pour soi
- `DELETE /conversations/:id` — retirer le DM de sa liste
- `DELETE /conversations/:id/messages/:messageId` — auteur ou staff
