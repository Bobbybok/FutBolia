# Phases 5–6 — Classique & Mercato

## Phase 5 (Classique)

- Statuts d’équipe : `forming` → `complete` → `validated`
- Effectif complet = nombre de titulaires atteint
- Organisateur : `POST /teams/:id/validate`
- Joueur : `POST /teams/:id/leave` (sauf capitaine)

## Phase 6 (Sélection / Mercato)

- Mode tournoi `selection`
- Organisateur crée des équipes + assigne un sélectionneur (à la création ou depuis le détail d’équipe)
- Rôle tournoi `selector` + `teams.selector_id`
- `POST /tournaments/:id/selectors` · `POST /teams/:id/selector`
- `GET /tournaments/:id/mercato`
- `POST /mercato/offers`
- `POST /mercato/offers/:id/accept|reject`
- Acceptation en **transaction SQL** (`FOR UPDATE`) pour éviter le double recrutement
