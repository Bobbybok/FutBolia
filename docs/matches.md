# Phase 7 — Matchs, scores, classement

## Règles

- Seul l’**organisateur** crée / génère / saisit / annule les matchs
- Points : victoire **3**, nul **1**, défaite **0**
- Départage : différence de buts → buts marqués → nom
- Round-robin : chaque équipe rencontre chaque autre **une** fois (paires déjà présentes ignorées)
- Match `finished` → scores obligatoires ; suppression interdite (annuler à la place)
- Premier match → tournoi passe en `in_progress` s’il était en `registration_open`

## API

- `GET /tournaments/:id/matches`
- `GET /tournaments/:id/standings`
- `POST /tournaments/:id/matches`
- `POST /tournaments/:id/matches/generate-round-robin`
- `PATCH /matches/:id`
- `POST /matches/:id/cancel`
- `DELETE /matches/:id` (uniquement `scheduled`)
