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

Clone :

```bat
git clone https://github.com/Bobbybok/FutBolia.git
cd FutBolia
```

---

## Prérequis

- Git
- Node.js 20+
- Flutter 3.24+ (stable) — dans le PATH
- Docker Desktop (recommandé pour PostgreSQL) **ou** une instance PostgreSQL 16
- Android Studio + Android SDK (téléphone ou émulateur)

---

## Configuration API

Le template est à la **racine** du dépôt (`.env.example`), pas dans `services/api`.

```bat
cd FutBolia
copy .env.example services\api\.env
```

Édite `services/api/.env` :

- `JWT_ACCESS_SECRET` et `JWT_REFRESH_SECRET` (au moins 32 caractères chacun)
- mot de passe Postgres : **doit rester identique** à `POSTGRES_PASSWORD` dans `docker-compose.yml` (valeur d’exemple : `futbolia_dev_change_me`)

**Ne commit jamais** `services/api/.env`.

---

## Base de données (DEV)

```bat
cd FutBolia
docker compose up -d
```

Vérifie que le conteneur `futbolia-postgres-dev` est healthy.

Chaque développeur a **sa propre base locale** (Docker). Les comptes créés sur un PC n’existent pas sur un autre.

**Neon (optionnel)** : `neon login` puis `neon link` à la racine. L’API lit `DATABASE_URL_UNPOOLED` depuis `services/api/.env` ou `.env.local`. Mets `DATABASE_SSL=true`. Évite la branche `production` pour `start:dev` (TypeORM `synchronize` est actif hors `NODE_ENV=production`).

---

## Lancer l’API

```bat
cd FutBolia\services\api
npm install
npm run start:dev
```

Vérifie : [http://localhost:3000/api/v1/health](http://localhost:3000/api/v1/health)

Sans Postgres : mets `DATABASE_ENABLED=false` dans `.env`.

- **API en ligne (Render free)** : [docs/render-api.md](docs/render-api.md) — Blueprint `render.yaml` + Neon
- Téléphone → Render (défaut) : `.\scripts\launch-phone.ps1` ou le raccourci `Flutter.lnk`
- Téléphone → API locale : `.\scripts\launch-phone.ps1 -Local`

---

## Lancer l’app mobile

```bat
cd FutBolia\apps\mobile
flutter pub get
```

Émulateur / téléphone : l’URL API par défaut pointe vers Render  
`https://futbolia-api.onrender.com/api/v1` (voir [docs/render-api.md](docs/render-api.md)).

**Téléphone physique** : débogage USB activé. Le raccourci `Flutter.lnk` (ou `launch-phone.bat`) utilise Render. Pour l’API de **ton** PC (même Wi‑Fi) :

```bat
cd FutBolia\scripts
launch-phone.bat -Local
```

Si le téléphone n’atteint pas l’API locale, autorise le port **3000** dans le pare-feu Windows.

**PC (navigateur, hot reload)** — lien local [http://localhost:8080](http://localhost:8080) :

```bat
cd FutBolia\scripts
launch-pc.bat
```

Ou en CMD :

```bat
cd FutBolia\apps\mobile
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=https://futbolia-api.onrender.com/api/v1
```

---

## Travail en commun

```bat
git checkout main
git pull
git checkout -b feature/nom-de-ta-tache
```

Ensuite :

```bat
git add .
git commit -m "message"
git push -u origin feature/nom-de-ta-tache
```

Ouvre une **Pull Request vers `main`** sur GitHub : [Bobbybok/FutBolia](https://github.com/Bobbybok/FutBolia).

Ne pousse pas directement sur `main`. Ne commit pas `.env`.

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
