# Phase 2 — Authentification

## Endpoints

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/verify-email`
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
- Permissions vérifiées côté API

## E-mail (DEV)

Sans `SMTP_HOST`, les e-mails sont **loggés dans la console API**.
En DEV, `register` renvoie aussi `devEmailVerificationToken` pour tester la vérif sans boîte mail.
