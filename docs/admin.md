# Admin plateforme

Rôle `user` | `admin` (`users.global_role`). Les droits précis sont dans `admin_permissions`.

Les deux **admins principaux** ont toutes les permissions, dont `manage_admins`. Ils sont créés par seed, pas via l’inscription publique.

## Seed

Dans `services/api/.env` :

```
PRINCIPAL_ADMIN_1_EMAIL=
PRINCIPAL_ADMIN_1_PASSWORD=
PRINCIPAL_ADMIN_1_PSEUDO=
PRINCIPAL_ADMIN_2_EMAIL=
PRINCIPAL_ADMIN_2_PASSWORD=
PRINCIPAL_ADMIN_2_PSEUDO=
```

Lance l’API une fois (création des tables), puis :

```bat
cd services\api
npm run seed:principal-admins
```

Reconnecte-toi dans l’app pour un JWT à jour. L’onglet **Admin** apparaît si `role == admin`.

## Endpoints (fondation)

- `GET /admin/admins` — `manage_admins`
- `POST /admin/admins/:userId/grant`
- `PATCH /admin/admins/:userId/permissions`
- `DELETE /admin/admins/:userId/revoke`
- `GET /admin/users?q=` — `manage_users` ou `manage_admins`

Toute action grant/revoke est tracée dans `audit_logs` et invalide les refresh tokens de la cible.

Les modules users (ban), tournois, modération, stats, sécurité viendront ensuite.
