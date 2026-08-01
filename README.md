# HistorySiteDeployment

Deployment of the History Site application (UI + API) with Docker Compose.

The images are built and published by the CI of:
- https://github.com/CedKLEIN/HistorySiteFrontend -> `cedkl/history-site-ui`
- https://github.com/CedKLEIN/HistorySiteBackend  -> `cedkl/history-site-api`

This repository only pulls and starts them.

## How to start locally

```bash
cp .env.example .env
# edit .env: set SMTP_PASSWORD (Gmail app password)
docker compose up -d --build
```

Then open http://localhost:8080

## How to update to a new version

The CI publishes a new tagged image on each commit (v0.0.1, v0.0.2, ...).
To deploy it:

```bash
docker compose pull  # if UI_IMAGE/API_IMAGE point to a floating tag
docker compose up -d --build
```

Or pin an exact version in `.env`:
```
UI_IMAGE=cedkl/history-site-ui:v0.0.2
API_IMAGE=cedkl/history-site-api:v0.0.2
```

## Useful commands

```bash
# Logs
docker compose logs api
docker compose logs ui

# Access a container
docker exec -it historysite-api sh
docker exec -it historysite-ui sh

# Remove containers (keeps the SQLite volume)
docker compose down

# Full cleanup (containers + volume, WARNING: deletes the database)
docker compose down -v
```

## How to deploy on a VPS

```bash
ssh root@<your-server-ip>

# Install Docker
# https://docs.docker.com/engine/install/ubuntu/

# Clone the repo
git clone https://github.com/CedKLEIN/HistorySiteDeployment.git /app
cd /app

# Configure
cp .env.example .env
nano .env   # set SMTP_PASSWORD (and UI_PORT if you want)

# Start
docker login   # with the cedkl Docker Hub account
docker compose up -d --build

# Check
curl http://localhost:8080
```

## Point a domain to the app (optional)

Install Nginx and create `/etc/nginx/sites-available/historysite`:

```nginx
server {
    listen 80;
    server_name yourdomain.fr www.yourdomain.fr;

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

HTTPS with Let's Encrypt:

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d yourdomain.fr -d www.yourdomain.fr
sudo certbot renew --dry-run
```

## Database

The SQLite database lives in the named volume `historydata` (`/data/history.db` inside the `api` container).
The API creates and seeds it automatically on first start. Backup it with:

```bash
docker run --rm -v historysitedeployment_historydata:/data -v "$PWD":/backup alpine tar czf /backup/historydata.tar.gz -C /data .
```

# ERRORS

## ERROR 1: unable to open database file

```
Microsoft.Data.Sqlite.SqliteException (0x80004005): SQLite Error 14: 'unable to open database file'
```

The `init-api` container creates `/data` with the right permissions on the volume.
If it still happens, force a clean restart:

```bash
docker compose down -v
docker compose up -d --build
```
