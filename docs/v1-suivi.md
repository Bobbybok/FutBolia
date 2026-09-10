# FutBolia / MatchArena — suivi V1

Source : cahier `FutBolia V1.docx` (sept. 2026) recoupé avec le code au **10 sept. 2026**.

**Pas de second dossier** : le détail technique reste dans `docs/*.md` (auth, tournois, chat…). Ce fichier = résumé + cases à cocher. Canvas : mêmes infos, cases cliquables.

**Comment valider** : les items **livrés et actifs** sont déjà en `- [x]`. Décoche si ça ne marche pas. Sous chaque ligne du canvas : **Résumé** (fermé, clique pour ouvrir).

Statuts : **livré** · **pas activé** (code là, pas allumé) · **à faire**.

---

## Résumé des choses faites

L’app **MatchArena** (repo FutBolia) tourne sur Flutter (Android + preview web) + API NestJS sur Render + Postgres Neon. On se connecte, on crée/rejoint des tournois (public ou privé par **invitation**, plus de code), on gère les **équipes**, le **mercato** (mode Sélection), les **matchs / scores / classement**, et les **matchs pickup**.

Côté social : **amis** (demande depuis le profil public), **chat tournoi**, **chat d’équipe** et **chat privé** en temps réel (Socket.io), overlay Chat avec barre du bas toujours visible. **Tournois, équipes, matchs, mercato et pickup** se mettent à jour **en direct** pour tous les connectés (plus besoin de pull-to-refresh). Staff : **admin / modo**, édition d’utilisateurs, **signalements**. App : branding MatchArena, **thème sombre uniquement**, hub Profil (sport + photo + carrière + amis + réglages), **profil public** (ouvert à tout compte connecté).

Mots de passe hashés **Argon2**. JWT + refresh. Mot de passe oublié.

**Codé mais pas allumé** : push FCM (inactif sur le navigateur PC), vérif e-mail (désactivée, pas de domaine Resend), forum (API sans écran), **chat inter-équipes**.

**Pas fait** : carte du tournoi, écran forum, activer l’e-mail. **Partiel** : trophées joueur (mini-bilan oui).

---

## Produit

App football à 5 / futsal amateur : tournois, équipes, mercato (mode Sélection), matchs / scores / classement, chat.

| Couche | État |
| --- | --- |
| App | Flutter Android + preview web PC — branding **MatchArena** |
| API | NestJS `/api/v1` — Render `https://futbolia-api.onrender.com/api/v1` |
| Base | Neon Postgres partagée |
| Temps réel | Socket.io (chat **et** état live : équipes, tournois, matchs, pickup) |
| Push | FCM **codé, inactif sur le web PC** |
| Auth | JWT + refresh, mots de passe **Argon2** |

Barre : **Accueil · Tournois · Matchs · Chat · Profil** (+ Admin/Modo si staff).

Lancement : `scripts\launch-phone.ps1` · `-Local` · `scripts\launch-pc.ps1` · health `…/api/v1/health`.

---

## A. Livré et actif — déjà coché, tu peux décocher

### Compte

- [x] **A1** Inscription / connexion JWT + refresh
  <details><summary>Résumé</summary>

  Créer un compte puis se connecter avec **l’e-mail ou le pseudo** + mot de passe. Access token + refresh token. La session revient au relancement. Si l’access expire, le refresh en demande un nouveau.

  </details>
- [x] **A2** Mot de passe oublié / reset
  <details><summary>Résumé</summary>

  L’API envoie un lien/code. L’utilisateur choisit un nouveau mot de passe. Sans SMTP, le token est dans les logs serveur.

  </details>
- [x] **A3** Mots de passe hashés Argon2
  <details><summary>Résumé</summary>

  Jamais stockés en clair. Hash Argon2 à l’inscription, au reset et au changement. La connexion compare le hash.

  </details>

### Tournois, équipes, mercato, matchs

- [x] **A4** Créer / chercher / rejoindre un tournoi
  <details><summary>Résumé</summary>

  Onglet Tournois : créer, lister, chercher, détail (équipes, mercato, matchs, classement, chat). Public = rejoindre depuis l’app.

  </details>
- [x] **A5** Privé = invitation par pseudo (plus de code)
  <details><summary>Résumé</summary>

  Plus de code d’accès. Orga / hôte invite **n’importe quel joueur par pseudo** (plus seulement les amis). Sans invitation sur un privé → 403.

  </details>
- [x] **A6** Organisateur / admin : **supprimer** et **modifier** le tournoi
  <details><summary>Résumé</summary>

  Écran « Modifier le tournoi » (nom, lieu, date, mode, visibilité, statut). L’orga et un admin avec `manage_tournaments` peuvent modifier ou supprimer, **aussi depuis la carrière du profil**.

  </details>
- [x] **A7** Modes Classique et Sélection
  <details><summary>Résumé</summary>

  Classique : équipes formées puis validées par l’orga. Sélection : mercato via un sélectionneur.

  </details>
- [x] **A8** Équipes : effectif, capitaine, validation orga
  <details><summary>Résumé</summary>

  **Transfert de capitaine** : bouton visible seulement pour le capitaine, l’orga ou un admin. Bouton **Créer une équipe** en haut du tournoi. **Poste FIFA** (GB, DC, BU…) : appuyer sur le joueur. Capitaine, orga et admin : gestion totale même après validation. Tout changement (créer / supprimer une équipe, effectif) s’affiche **en direct** chez tous les joueurs connectés.

  </details>
- [x] **A9** Mercato : sélectionneur + offres
  <details><summary>Résumé</summary>

  L’orga nomme un sélectionneur. Offres envoyer / accepter / refuser. Une seule équipe par joueur (API).

  </details>
- [x] **A10** Matchs : round-robin, scores, classement
  <details><summary>Résumé</summary>

  Créer des matchs ou générer un round-robin. Saisir / annuler. Classement 3 / 1 / 0.

  </details>

### Social & chat

- [x] **A11** Chat tournoi Socket.io
  <details><summary>Résumé</summary>

  Fil commun aux participants. Temps réel Socket.io. Suppression auteur ou orga. Aussi dans l’overlay Chat. Même canal : listes et fiches (équipes, matchs, pickup) se rechargent sans pull-to-refresh.

  </details>
- [x] **A21** Chat d’équipe + roster orga
  <details><summary>Résumé</summary>

  Un fil par équipe, **membres de l’équipe seulement** (+ orga / admin pour modérer). Dans l’onglet Chat. L’orga ajoute / retire des participants du tournoi, place dans une équipe (clic ou glisser). L’admin peut tout faire.

  </details>
- [x] **C1** Chat **inter-équipe** — **désactivé**
  <details><summary>Résumé</summary>

  Code encore là, mais **éteint** : plus de bouton, plus de fil dans Chat, l’API refuse. Pour rallumer plus tard.

  </details>
- [x] **A12** Amis : ajouter, retirer, inviter
  <details><summary>Résumé</summary>

  Profil → Amis : recherche pseudo, demandes, retirer, inviter à un tournoi/match. **Profil public** : bouton « Ajouter en ami ».

  </details>
- [x] **A13** Chat privé + badge
  <details><summary>Résumé</summary>

  DM entre amis, **co-participants** d’un même tournoi / match libre, ou staff. Overlay Chat, badge non-lus. Profil public : **Ajouter en ami** + Message.

  </details>
- [x] **A14** Matchs pickup
  <details><summary>Résumé</summary>

  Onglet Matchs : créer, lister, rejoindre. Privé = invitation par pseudo. Les joueurs arrivent **sans équipe** (comme au tournoi) ; l’hôte les glisse vers A ou B. Hôte / admin : ajouter / retirer, profil, DM.

  </details>

### Staff & app

- [x] **A15** Admin / Modo
  <details><summary>Résumé</summary>

  Onglet staff. L’admin (droit `manage_users` / `manage_tournaments`) peut **modifier et supprimer** profils, tournois, matchs, équipes, matchs libres. Même actions depuis le détail d’un tournoi / match / **profil public** (carrière : retirer du profil ou supprimer l’événement). L’API refuse sans le droit.

  </details>
- [x] **A16** Signalements
  <details><summary>Résumé</summary>

  Signaler joueur / message. File modo : traiter, fermer, rouvrir. Messages supprimés listés.

  </details>
- [x] **A18** Thème sombre
  <details><summary>Résumé</summary>

  App **sombre uniquement** (plus de switch clair). Cartes, badges, champs et dialogs sur le fond MatchArena.

  </details>
- [x] **A19** Barre persistante + overlay Chat
  <details><summary>Résumé</summary>

  Accueil / Tournois / Matchs / Chat / Profil. Overlay Chat. Même nom partout.

  </details>
- [x] **A20** Profil joueur : postes FIFA, expérience, photo, carrière, profil public
  <details><summary>Résumé</summary>

  Formulaire Profil : jusqu’à **5 postes** (GB, DG/DC/DD, MG/MC/MD/MCD, AG/BU/AD) dans l’ordre de préférence, pied fort, taille/poids, palier loisir → pro + année, dispos, photo. Mini-bilan (tournois / matchs / orga / cap.). Carrière : masquer, **retirer du profil**, ou **supprimer l’événement** (orga / admin `manage_tournaments`). **Tout compte connecté** peut ouvrir un profil (photo, postes, mini-bilan, carrière non masquée). Photo stockée en base (pas R2). Indicatif : ne pilote pas le mercato.

  </details>

---

## Pas activé — code présent, pas allumé

Ne pas traiter comme OK tant que ce n’est pas branché.

- [ ] **A17** Notifications push FCM
  <details><summary>Résumé</summary>

  Code + interrupteur Réglages. **Inactif sur le navigateur PC.** Téléphone seulement si Firebase est configuré. Le chat in-app marche sans push.

  </details>
- [ ] **B1** Vérification e-mail
  <details><summary>Résumé</summary>

  Écran + API prêts. **Désactivée** (`EMAIL_VERIFICATION_REQUIRED=false`). Comptes marqués vérifiés. Pour allumer : domaine Resend.

  </details>
- [x] **B2** Poste / pied / expérience / photo (désormais dans le formulaire, voir A20)
  <details><summary>Résumé</summary>

  Hub Profil : prénom, ville, bio, **postes FIFA (max 5)**, pied, taille/poids, expérience, dispos, photo. L’ancien champ `level` 1–5 reste en API mais n’est plus dans l’UI.

  </details>
- [ ] **B3** Forum tournoi
  <details><summary>Résumé</summary>

  API sujets / réponses OK. **Aucun écran** dans l’app.

  </details>
- [ ] **B4** Modération plus poussée
  <details><summary>Résumé</summary>

  Signalements déjà en A16. Manque ban dur, filtres de mots, modération forum.

  </details>

---

## C. À faire

- [ ] **C2** Carte du tournoi
  <details><summary>Résumé</summary>

  Pas encore codé. Zone du tournoi sur une carte, pas seulement un texte ville.

  </details>
- [x] **C3** Photos de **tournoi** + album
  <details><summary>Résumé</summary>

  Photo du tournoi (cover) : orga et admin `manage_tournaments`. Album : orga et admin ajoutent / suppriment ; les **capitaines** peuvent seulement ajouter (24 photos, JPEG/PNG/WebP, Postgres). Listes et fiche se mettent à jour en live.

  </details>
- [ ] **C4** Écran Forum
  <details><summary>Résumé</summary>

  Pas encore dans l’app. Brancher l’API forum (B3) sur un écran tournoi.

  </details>
- [ ] **C5** Activer la vérif e-mail
  <details><summary>Résumé</summary>

  Allumer B1 : domaine Resend + `EMAIL_VERIFICATION_REQUIRED=true`.

  </details>
- [x] **C6** Poste, pied, expérience + photo dans le formulaire (voir A20)
  <details><summary>Résumé</summary>

  Branché dans Profil. 5 postes FIFA + GB, palier d’expérience, photo, carrière, profil public.

  </details>

---

## D. À corriger / à aligner (déjà partiellement là)

- [x] **D1** Écran **modifier le tournoi** (A6) — orga + admin
- [x] **D2** Barre + overlay : **Chat** partout (corrigé)
- [ ] **D3** Restes de **codes d’accès** dans l’API / tests e2e (plus utilisés dans l’app)
- [ ] **D4** Docs `docs/chat.md` encore sur l’ancien polling 4 s
- [ ] **D5** Bouton « Vérifier e-mail » alors que la vérif est **désactivée**
- [x] **D6** Profil public (écran + mini-bilan + carrière masquable)
- [x] **D7** Cartes sombres (réglages, listes, chat)
- [ ] **D8** Trophées joueur — **mini-bilan** livré (A20), pas encore de trophées

---

## Travail à deux

`git pull` → modifier → commit + push → l’autre `git pull` + relance. Jamais de `.env` / secrets dans git.

Après un livrable : déplacer C/D vers A (actif) ou « Pas activé ». **Toute feature ajoutée / modifiée / désactivée / supprimée = MAJ de ce fichier + du canvas.**
