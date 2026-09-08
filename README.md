# FutBolia

Plateforme mobile dédiée au **football à 5, futsal et tournois amateurs** :
tournois, équipes, mercato (mode Sélection), matchs, classements, communauté.

> Première cible : **Android (APK)** — architecture prête pour **iOS** ensuite.

---

## Stack

| Couche | Technologie |
|--------|-------------|
| Mobile | Flutter |
| API | NestJS (TypeScript) |
| Base de données | PostgreSQL 16 |
| Auth | JWT + refresh (Phase 2) |
| Stockage images | Cloudflare R2 (Phase 2+) |
| Temps réel | Socket.io (phases Mercato / Chat) |
| Push | FCM (Phase 11) |

---

## Structure du dépôt

```
FutBolia/
├── apps/mobile/          # Application Flutter
├── services/api/         # API NestJS
├── docs/                 # Documentation technique
├── docker-compose.yml    # PostgreSQL local
├── .env.example          # Variables d'environnement (template)
└── README.md
```

---

## Prérequis

- Node.js 20+
- Flutter 3.24+ (stable)
- Git
- Docker Desktop (recommandé pour PostgreSQL) **ou** une instance PostgreSQL 16

> Sur cette machine de développement : si Docker n’est pas installé, lance l’API avec `DATABASE_ENABLED=false` pour un smoke test, puis installe Docker avant la Phase 2.

---

## Configuration

```bash
# À la racine du projet
cp .env.example services/api/.env
```

Adapte les secrets dans `services/api/.env` (ne jamais committer ce fichier).

---

## Base de données (DEV)

```bash
docker compose up -d
```

Vérifie que le conteneur `futbolia-postgres-dev` est healthy.

---

## Lancer l’API

```bash
cd services/api
npm install
npm run start:dev
```

- Health : [http://localhost:3000/api/v1/health](http://localhost:3000/api/v1/health)
- Sans Postgres : mets `DATABASE_ENABLED=false` dans `.env`
- **API en ligne (Render free)** : [docs/render-api.md](docs/render-api.md) — Blueprint `render.yaml` + Neon
- Téléphone → Render : `.\scripts\launch-phone.ps1 -Remote`

---

## Lancer l’app mobile

```bash
cd apps/mobile
flutter pub get
flutter run
```

Émulateur Android : l’URL API par défaut pointe vers `http://10.0.2.2:3000/api/v1`.

---

## Environnements

| Environnement | Base de données | Usage |
|---------------|-----------------|-------|
| `development` | `futbolia_dev` (Docker local) | Développement |
| `production` | instance séparée (jamais la DB de DEV) | Utilisateurs réels |

---

## Tests

```bash
# API
cd services/api && npm test

# Mobile
cd apps/mobile && flutter test
```

---

## Build APK (plus tard — Phase 13)

```bash
cd apps/mobile
flutter build apk --release
```

---

## Sécurité

- Secrets uniquement dans `.env` (gitignored)
- Permissions et règles métier **toujours** côté API
- Pas de données fictives permanentes pour masquer une feature incomplete

---

## Roadmap (résumé)

1. **Phase 1** — Foundation ✅
2. **Phase 2** — Authentification & profil ✅
3. **Phase 3** — Tournois ✅
4. **Phase 4** — Équipes ✅
5. **Phase 5** — Mode Classique ✅
6. **Phase 6** — Sélection / Mercato ✅
7. **Phase 7** — Matchs, scores, classements ✅
8. **Phase 8** — Stats / trophées _(reportée)_
9. **Phase 9** — Chat par tournoi ✅
10. **Phases 10–11** — Forum UI, modération, notifications
11. **Phases 12–13** — Tests & APK production

Décisions détaillées : voir `docs/architecture.md`.

---

## Licence

Projet privé — FutBolia.
