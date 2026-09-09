# Vérification e-mail (code à 6 chiffres)

**Actuellement désactivée** (`EMAIL_VERIFICATION_REQUIRED=false`) tant qu’il n’y a pas de domaine Resend.

Quand elle est activée : à l’inscription, FutBolia envoie un **code à 6 chiffres** (valable **15 minutes**).  
L’utilisateur le saisit dans l’app. Il peut **renvoyer** le code (1 / minute).

## Activation

Variable `EMAIL_VERIFICATION_REQUIRED` :

- `false` (défaut actuel) : comptes marqués vérifiés à l’inscription / connexion, pas d’e-mail envoyé
- `true` : codes à 6 chiffres via Resend/SMTP (nécessite un domaine pour envoyer à n’importe qui)

## Envoi des e-mails

Ordre de priorité :

1. **Resend** si `RESEND_API_KEY` est défini (recommandé sur Render)
2. **SMTP** si `SMTP_HOST` (+ `SMTP_PORT` / `SMTP_USER` / `SMTP_PASSWORD`)
3. Sinon : log serveur uniquement (DEV / e2e) + le code peut être renvoyé dans `devEmailVerificationToken`

### Resend (gratuit)

1. Compte sur [https://resend.com](https://resend.com)
2. Créer une API key
3. Sur Render → Environment :
   - `RESEND_API_KEY=re_...`
   - `EMAIL_FROM=FutBolia <onboarding@resend.dev>`  
     (domaine vérifié plus tard pour un from custom, ex. `noreply@ton-domaine.fr`)

### SMTP

```
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=...
SMTP_PASSWORD=...
EMAIL_FROM=FutBolia <noreply@ton-domaine.fr>
```

## API

- `POST /auth/register` → envoie le code
- `POST /auth/verify-email` `{ "token": "123456" }`
- `POST /auth/resend-verification` (JWT) → nouveau code

## Mobile

Écran **Vérifier l’e-mail** : saisie 6 chiffres + bouton renvoyer.
