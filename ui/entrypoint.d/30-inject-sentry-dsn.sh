#!/bin/sh
# Injecte le DSN Sentry dans index.html au démarrage du conteneur nginx, à
# partir de la variable d'environnement VITE_SENTRY_DSN (définie dans .env).
# Sans VITE_SENTRY_DSN, le placeholder reste et le frontend désactive Sentry.
set -e

file=/usr/share/nginx/html/index.html

if [ -n "$VITE_SENTRY_DSN" ]; then
  sed -i "s|__SENTRY_DSN__|$VITE_SENTRY_DSN|g" "$file"
fi
