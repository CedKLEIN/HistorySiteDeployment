# HistorySiteDeployment

Déploiement de l'application History Site (UI + API) avec Docker Compose.

Les images sont construites et publiées par la CI de :
- https://github.com/CedKLEIN/HistorySiteFrontend -> `cedkl/history-site-ui`
- https://github.com/CedKLEIN/HistorySiteBackend  -> `cedkl/history-site-api`

Ce dépôt ne fait que les récupérer et les démarrer.

---

## Variables d'environnement (`.env`)

Copier `.env.example` vers `.env` puis renseigner **toutes** les variables :

| Variable | Valeur production | Description |
|---|---|---|
| `HISTORY_UI_IMAGE` | `cedkl/history-site-ui:latest` | Image du frontend (ou version figée `vX.Y.Z`) |
| `HISTORY_API_IMAGE` | `cedkl/history-site-api:latest` | Image du backend (ou version figée `vX.Y.Z`) |
| `HISTORY_UI_PORT` | `8080` | Port exposé du frontend (http://IP:8080) |
| `BACKEND_URL` | `http://api:8080` | URL interne vers l'API (`api` = nom du service compose, réseau interne) |
| `VITE_SENTRY_DSN` | *vide* | DSN Sentry du monitoring erreurs frontend (optionnel, vide = désactivé). Injecté dans `index.html` au démarrage du conteneur `ui`. |
| `FRONTEND_URL` | `https://roisempereurs.fr` | URL publique du site, utilisée pour construire les liens de réinitialisation de mot de passe envoyés par e-mail (`SiteConfiguration__FrontendBaseUrl`). En local : `http://localhost:8080`. |
| `HISTORY_SMTP_PASSWORD` | *Gmail app password* | **Obligatoire** pour l'envoi des messages de contact. Se crée ici : https://myaccount.google.com/apppasswords (vérification en deux étapes requise). Variable d'env `SiteConfiguration__Email__Password` du backend. |
| `HISTORY_ADMIN_EMAIL` | `souverainsdefrance1214@gmail.com` | Email(s) admin qui reçoivent les messages de contact (`SiteConfiguration__AdminEmails__0`) **et** email du compte admin créé au démarrage (`SiteConfiguration__AdminSeed__Email`) |
| `HISTORY_JWT_SECRET` | *chaîne longue et aléatoire* | **Obligatoire.** Clé de signature des jetons JWT (`SiteConfiguration__Jwt__Token`). Sans elle, le backend utilise une clé de développement insuffisante en production. |
| `HISTORY_ADMIN_PASSWORD` | *mot de passe fort* | **Obligatoire si vous voulez le compte admin.** Si vide, **aucun** compte admin n'est créé en production (`SiteConfiguration__AdminSeed__Password`). |
| `HISTORY_JWT_ISSUER` | `HistorySiteBackend` | Issuer des jetons (optionnel, ne pas changer si rien n'est modifié du côté frontend) |
| `HISTORY_JWT_AUDIENCE` | `HistorySiteFrontend` | Audience des jetons (optionnel, idem) |
| `HISTORY_BLUESKY_ENABLED` | `false` | Souverain du jour sur Bluesky (voir « Réseaux sociaux » plus bas). |
| `HISTORY_BLUESKY_HANDLE` | *vide* | Compte Bluesky du site, ex. `roisempereurs.bsky.social`. |
| `HISTORY_BLUESKY_APP_PASSWORD` | *mot de passe d'application* | Créé dans Bluesky (Réglages > Confidentialité et sécurité > Mots de passe d'application). Jamais le mot de passe du compte. |
| `HISTORY_PINTEREST_ENABLED` | `false` | Sert et alimente le flux `/api/social/pinterest.rss` que Pinterest publie seul. |

> Gmail app password et `HISTORY_JWT_SECRET` **ne doivent jamais** être commités : `.env` est dans `.gitignore`.

### Préfixe `HISTORY_`

Les variables propres à ce déploiement sont préfixées `HISTORY_`. Le même VPS héberge
`SportSiteDeployment` (denivio.fr), dont les variables sont préfixées `DENIVIO_` : sans
préfixe, les deux `.env` partageaient neuf noms identiques (`UI_IMAGE`, `API_IMAGE`,
`UI_PORT`, `JWT_SECRET`, `JWT_ISSUER`, `JWT_AUDIENCE`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`,
`SMTP_PASSWORD`).

Docker Compose donne la priorité aux variables **du shell** sur celles du fichier `.env`.
Un `set -a; . ./.env; set +a` lancé depuis un déploiement exporte donc ses valeurs dans le
shell, et le `docker compose` suivant, lancé depuis l'autre déploiement, les utilise à la
place des siennes — sans aucun message. Le 06/09/2026, historysite a ainsi été construit à
partir des images `cedkl/denivio-*` et a tenté de se lier au port 8081.

Deux règles en découlent :

- Toute nouvelle variable de ce dépôt prend le préfixe `HISTORY_`.
- Ne jamais sourcer un `.env` dans le shell interactif. Utiliser un sous-shell, dont les
  exports disparaissent avec lui : `( set -a; . ./.env; set +a; <commande> )`.

> **Mise à jour d'un VPS déjà déployé.** Le `.env` du serveur n'est pas versionné : il faut
> le renommer à la main **avant** de relancer Compose, sinon les variables sont vues comme
> vides (sans `HISTORY_JWT_SECRET`, l'API refuse de démarrer en production).
>
> ```bash
> sed -i -E 's/^(UI_IMAGE|API_IMAGE|UI_PORT|JWT_SECRET|JWT_ISSUER|JWT_AUDIENCE|ADMIN_EMAIL|ADMIN_PASSWORD|SMTP_PASSWORD)=/HISTORY_\1=/' .env
> ```

---

## Réseaux sociaux (souverain du jour)

L'API publie seule, sans intervention ni coût : chaque jour à **9 h (Paris)**, une fiche sur
Bluesky et deux fiches ajoutées au flux RSS que Pinterest lit ; le **vendredi**, une époque
(dynastie ou régime) en plus, jusqu'à épuisement. Une fiche ne passe qu'une fois par réseau ; une
publication manquée (API arrêtée, Bluesky injoignable) est retentée toutes les heures du même jour.
Les images (1000 × 1500, JPEG) sont dessinées par l'API : portrait du domaine public vérifié fichier
par fichier, sinon composition typographique.

- Image d'une fiche : `https://roisempereurs.fr/api/rulers/<slug>/image.jpg`
- Image d'une époque : `https://roisempereurs.fr/api/eras/<slug>/image.jpg`
- Flux Pinterest : `https://roisempereurs.fr/api/social/pinterest.rss` (404 tant que Pinterest est coupé)

Vérifier après activation :

```bash
docker compose logs api | grep -i "souverain du jour\|époque de la semaine"
```

---

## Monitoring des erreurs (Sentry)

Le frontend remonte ses erreurs JS vers Sentry (gratuit jusqu'à ~5 000 erreurs/mois).

### 1. Créer le projet Sentry

1. Créer un compte sur https://sentry.io (le plan gratuit suffit).
2. Créer un projet de type **Vite/React**.
3. Copier le **DSN** (Settings → Projects → `<projet>` → Client Keys (DSN)) : `https://xxxx@sentry.io/1234567`.

### 2. Configurer le DSN

Le DSN se renseigne dans `.env` du serveur (variable `VITE_SENTRY_DSN`) :

```ini
VITE_SENTRY_DSN=https://xxxx@sentry.io/1234567
```

Il est injecté dans `index.html` au démarrage du conteneur `ui` par un script nginx.
Un simple `docker compose up -d --build` suffit. Vide ou absent = Sentry désactivé
(le DSN est public, pas de secret).

### 3. Recevoir les alertes par email

1. Dashboard Sentry : **Alerts → Create Alert** → condition *« An issue is created »* →
   action **« Send an email »** aux membres du projet.
2. Vérifier l'email du compte dans **Account → Email Addresses** : l'email doit être
   **confirmé**, sinon les alertes ne partent pas.

### 4. Health check de l'API

L'API expose `GET /healthz` (JSON : statut global + check de la base SQLite) :

```bash
curl http://localhost:8080/healthz
# {"status":"Healthy","checks":[{"name":"database","status":"Healthy",...}]}
```

En production, les logs de l'API sont émis en **JSON structuré** (`docker compose logs api`).

---

## Ce qu'il faut configurer en production

Au minimum, dans le fichier `.env` :

```ini
HISTORY_SMTP_PASSWORD=abcd efgh ijkl mnop    # envoi des messages de contact (Gmail app password)
HISTORY_JWT_SECRET=<au moins 64 caractères aléatoires>   # signe les jetons de connexion (sinon l'API refuse les comptes)
HISTORY_ADMIN_PASSWORD=<mot de passe fort>   # crée le compte administrateur au premier démarrage
HISTORY_ADMIN_EMAIL=souverainsdefrance1214@gmail.com       # email de ce compte admin (+ destinataire des messages de contact)
```

Si `HISTORY_ADMIN_PASSWORD` est laissé vide, **aucun** compte admin n'est créé : les visiteurs
peuvent toujours s'inscrire (rôle utilisateur), mais personne n'aura le rôle administrateur.

> En développement local, le compte admin **`souverainsdefrance1214@gmail.com` / `HistoryAdminDev1!`** est
> créé automatiquement (voir `appsettings.Development.json`). Ce comportement n'existe qu'en dev.

Exemple de `.env` production :

```ini
HISTORY_UI_IMAGE=cedkl/history-site-ui:v0.0.2
HISTORY_API_IMAGE=cedkl/history-site-api:v0.0.2
HISTORY_UI_PORT=8080
BACKEND_URL=http://api:8080
HISTORY_SMTP_PASSWORD=abcd efgh ijkl mnop
HISTORY_ADMIN_EMAIL=souverainsdefrance1214@gmail.com
HISTORY_JWT_SECRET=uneLongueChaineAleatoireDePlusDe64CaracteresPourSignerLesJetons
HISTORY_ADMIN_PASSWORD=MonMotDePasseAdminFort1!
```

---

## Démarrage local

```bash
docker compose up -d --build
```

Puis ouvrir http://localhost:8080

---

## Déploiement production (VPS)

```bash
ssh root@<ip-du-serveur>

# 1. Installer Docker
# https://docs.docker.com/engine/install/ubuntu/

# 2. Récupérer le dépôt
git clone https://github.com/CedKLEIN/HistorySiteDeployment.git /app
cd /app

# 3. Configurer les variables (voir le tableau ci-dessus)
cp .env.example .env
nano .env

# 4. Se connecter au Docker Hub (compte cedkl)
docker login

# 5. Démarrer
docker compose up -d --build

# 6. Vérifier
curl http://localhost:8080/api/rulers   # doit répondre une liste JSON
```

---

## Mise à jour vers une nouvelle version

La CI publie une nouvelle image taguée à chaque commit (v0.0.1, v0.0.2, ...).

```bash
# Version flottante : récupère la dernière
docker compose up -d --build

# Version figée dans .env
docker compose pull
docker compose up -d
```

---

## Commandes utiles

```bash
# Logs
docker compose logs api
docker compose logs ui

# Accéder aux conteneurs
docker exec -it historysite-api sh
docker exec -it historysite-ui sh

# Arrêter (garde la base SQLite)
docker compose down

# Tout supprimer (volume compris, SUPPRIME la base)
docker compose down -v
```

---

## Domain + HTTPS (optionnel)

Installer Nginx, créer `/etc/nginx/sites-available/historysite` :

```nginx
server {
    listen 80;
    server_name votre-domaine.fr www.votre-domaine.fr;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/historysite /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
sudo rm /etc/nginx/sites-enabled/default && sudo systemctl reload nginx
```

HTTPS Let's Encrypt :

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d votre-domaine.fr -d www.votre-domaine.fr
sudo certbot renew --dry-run
```

---

## Base de données

La base SQLite vit dans le volume nommé `historydata` (`/data/history.db` dans le conteneur `api`).
L'API la crée et la remplit automatiquement au premier démarrage.

### Sauvegarde automatique

L'API sauvegarde automatiquement `history.db` chaque jour à **03:00 UTC** (configurable via
`SiteConfiguration__Backup__Hour`) en utilisant l'API de backup en ligne de SQLite : le snapshot
est cohérent même si la base est en cours d'écriture (mode WAL géré).

- Fichiers : `./backups/history-YYYYMMDD-HHmmss.db` (bind mount hôte `/backup` dans le conteneur).
- Rétention : les **14** derniers backups sont conservés (`SiteConfiguration__Backup__RetentionCount`).
- Le dossier `./backups` est créé et rendu inscriptible par `init-api` au démarrage.
- Les backups **survivent** à `docker compose down -v` (le bind mount hôte n'est pas un volume Docker).

Désactivation/ajustement : passer `SiteConfiguration__Backup__Enabled=false` ou changer les valeurs
dans `docker-compose.yml`.

Vérifier le bon fonctionnement :

```bash
ls -la backups/          # doit contenir history-*.db
docker compose logs api | grep -i backup
```

### Restauration

```bash
# 1. Arrêter l'API (les écritures doivent être stoppées)
docker compose stop api

# 2. Copier un backup vers la base (remplace l'existant + ses fichiers WAL)
docker run --rm -v historysitedeployment_historydata:/data -v "$PWD/backups":/backup \
  alpine sh -c "rm -f /data/history.db-wal /data/history.db-shm && cp /backup/history-20260101-030000.db /data/history.db"

# 3. Redémarrer l'API
docker compose start api
```

> Backup manuel ponctuel (équivalent de l'ancienne commande) :
> ```bash
> docker run --rm -v historysitedeployment_historydata:/data -v "$PWD":/backup alpine tar czf /backup/historydata.tar.gz -C /data .
> ```

---

# ERREURS

## ERROR 1: unable to open database file

```
Microsoft.Data.Sqlite.SqliteException (0x80004005): SQLite Error 14: 'unable to open database file'
```

Le conteneur `init-api` crée `/data` avec les bons droits sur le volume.
Si l'erreur persiste, redémarrage complet :

```bash
docker compose down -v
docker compose up -d --build
```

## ERROR 2: le conteneur api ne démarre pas (SMTP)

L'API démarre même sans `HISTORY_SMTP_PASSWORD`, mais les messages de contact ne seront pas envoyés
(un warning est logué). Vérifier dans les logs :

```bash
docker compose logs api
```
