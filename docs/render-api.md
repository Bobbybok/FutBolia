# API en ligne (Render free + Neon)

L’API NestJS se déploie sur [Render](https://render.com) (plan **Free**).  
La base reste **Neon** (déjà partagée).

URL cible typique : `https://futbolia-api.onrender.com/api/v1`

> Le free tier **s’endort** après ~15 min d’inactivité. Le premier appel peut prendre 30–60 s.

## 1. Déployer (une seule fois)

1. Crée un compte sur [https://dashboard.render.com](https://dashboard.render.com) (GitHub OK).
2. **New** → **Blueprint** → sélectionne le repo `Bobbybok/FutBolia`.
3. Render lit `render.yaml` à la racine → service `futbolia-api`.
4. Avant / juste après le premier deploy, ouvre le service → **Environment** et renseigne :
   - `DATABASE_URL` = connection string **Neon** (idéalement **pooled** / `-pooler`, avec `sslmode=require`)
   - `APP_URL` = `https://futbolia-api.onrender.com` (adapte si le nom diffère)
5. **Manual Deploy** → **Deploy latest commit** si besoin.

Health check : `GET https://<ton-service>.onrender.com/api/v1/health`  
Attendu : `"status":"ok"` et `"database":{"connected":true}`.

## 2. Récupérer `DATABASE_URL` (Neon)

Console Neon → projet **FutBolia** → Connection string → **pooled**  
ou dans ton `.env.local` / `services/api/.env` (ne jamais committer).

## 3. App mobile

Sur téléphone / émulateur, pointe vers Render :

```bash
flutter run --dart-define=API_BASE_URL=https://futbolia-api.onrender.com/api/v1
```

Ou adapte le raccourci `scripts/launch-phone.ps1` pour utiliser cette URL au lieu de l’IP LAN.

## 4. Ton ami

1. `git pull`
2. Plus besoin de lancer Nest en local s’il utilise l’URL Render.
3. Même base Neon → mêmes comptes / tournois.

## 5. Deploys suivants

Chaque `git push` sur `main` (changements sous `services/api/`) redéploie automatiquement.
