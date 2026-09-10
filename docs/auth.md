# Phase 2 — Authentification

## Endpoints

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login` — e-mail **ou** pseudo + mot de passe
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/verify-email` — code à **6 chiffres**
- `POST /api/v1/auth/resend-verification` (JWT)
- `POST /api/v1/auth/forgot-password`
- `POST /api/v1/auth/reset-password`
- `POST /api/v1/auth/change-password` (JWT)
- `POST /api/v1/auth/change-email` (JWT)
- `POST /api/v1/auth/confirm-email-change`
- `DELETE /api/v1/auth/account` (JWT)
- `GET /api/v1/users/me` (JWT)
- `PATCH /api/v1/users/me` (JWT)

## Sécurité

- Mots de passe hashés avec **argon2**
- Access JWT court + refresh token stocké hashé (SHA-256)
- Permissions vérifiées côté API (`@RequirePermission` sur `/admin/*`)
- JWT : `role` + `permissions` (reconnecte-toi après un changement de droits)

Voir [admin.md](./admin.md) pour les comptes admin principaux.

## E-mail

Voir [email-verification.md](./email-verification.md) — code 6 chiffres via **Resend** ou SMTP.  
Sans fournisseur mail (DEV), le code est loggé et peut apparaître dans `devEmailVerificationToken`.
