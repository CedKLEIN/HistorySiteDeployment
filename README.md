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
| `UI_IMAGE` | `cedkl/history-site-ui:latest` | Image du frontend (ou version figée `vX.Y.Z`) |
| `API_IMAGE` | `cedkl/history-site-api:latest` | Image du backend (ou version figée `vX.Y.Z`) |
| `UI_PORT` | `8080` | Port exposé du frontend (http://IP:8080) |
| `BACKEND_URL` | `http://api:8080` | URL interne vers l'API (`api` = nom du service compose, réseau interne) |
| `FRONTEND_URL` | `https://roisempereurs.fr` | URL publique du site, utilisée pour construire les liens de réinitialisation de mot de passe envoyés par e-mail (`SiteConfiguration__FrontendBaseUrl`). En local : `http://localhost:8080`. |
| `SMTP_PASSWORD` | *Gmail app password* | **Obligatoire** pour l'envoi des messages de contact. Se crée ici : https://myaccount.google.com/apppasswords (vérification en deux étapes requise). Variable d'env `SiteConfiguration__Email__Password` du backend. |
| `ADMIN_EMAIL` | `souverainsdefrance1214@gmail.com` | Email(s) admin qui reçoivent les messages de contact (`SiteConfiguration__AdminEmails__0`) **et** email du compte admin créé au démarrage (`SiteConfiguration__AdminSeed__Email`) |
| `JWT_SECRET` | *chaîne longue et aléatoire* | **Obligatoire.** Clé de signature des jetons JWT (`SiteConfiguration__Jwt__Token`). Sans elle, le backend utilise une clé de développement insuffisante en production. |
| `ADMIN_PASSWORD` | *mot de passe fort* | **Obligatoire si vous voulez le compte admin.** Si vide, **aucun** compte admin n'est créé en production (`SiteConfiguration__AdminSeed__Password`). |
| `JWT_ISSUER` | `HistorySiteBackend` | Issuer des jetons (optionnel, ne pas changer si rien n'est modifié du côté frontend) |
| `JWT_AUDIENCE` | `HistorySiteFrontend` | Audience des jetons (optionnel, idem) |

> Gmail app password et `JWT_SECRET` **ne doivent jamais** être commités : `.env` est dans `.gitignore`.

---

## Ce qu'il faut configurer en production

Au minimum, dans le fichier `.env` :

```ini
SMTP_PASSWORD=abcd efgh ijkl mnop    # envoi des messages de contact (Gmail app password)
JWT_SECRET=<au moins 64 caractères aléatoires>   # signe les jetons de connexion (sinon l'API refuse les comptes)
ADMIN_PASSWORD=<mot de passe fort>   # crée le compte administrateur au premier démarrage
ADMIN_EMAIL=souverainsdefrance1214@gmail.com       # email de ce compte admin (+ destinataire des messages de contact)
```

Si `ADMIN_PASSWORD` est laissé vide, **aucun** compte admin n'est créé : les visiteurs
peuvent toujours s'inscrire (rôle utilisateur), mais personne n'aura le rôle administrateur.

> En développement local, le compte admin **`souverainsdefrance1214@gmail.com` / `HistoryAdminDev1!`** est
> créé automatiquement (voir `appsettings.Development.json`). Ce comportement n'existe qu'en dev.

Exemple de `.env` production :

```ini
UI_IMAGE=cedkl/history-site-ui:v0.0.2
API_IMAGE=cedkl/history-site-api:v0.0.2
UI_PORT=8080
BACKEND_URL=http://api:8080
SMTP_PASSWORD=abcd efgh ijkl mnop
ADMIN_EMAIL=souverainsdefrance1214@gmail.com
JWT_SECRET=uneLongueChaineAleatoireDePlusDe64CaracteresPourSignerLesJetons
ADMIN_PASSWORD=MonMotDePasseAdminFort1!
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

L'API démarre même sans `SMTP_PASSWORD`, mais les messages de contact ne seront pas envoyés
(un warning est logué). Vérifier dans les logs :

```bash
docker compose logs api
```
