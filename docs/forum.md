# Phase 9b — Forum de tournoi (API)

Forum (sujets / réponses) — API disponible. UI mobile : à brancher ensuite.

## Règles

- Réservé aux **participants** du tournoi
- Poster / répondre : tout membre
- Supprimer : **auteur** ou **organisateur**

## API

- `GET /tournaments/:id/forum/posts`
- `POST /tournaments/:id/forum/posts` `{ title, body }`
- `GET /forum/posts/:postId` (détail + réponses)
- `POST /forum/posts/:postId/replies` `{ body }`
- `DELETE /forum/posts/:postId`
- `DELETE /forum/replies/:replyId`
