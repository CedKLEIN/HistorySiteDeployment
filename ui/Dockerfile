ARG UI_IMAGE
FROM ${UI_IMAGE}

WORKDIR /app
COPY entrypoint.d/30-inject-sentry-dsn.sh /docker-entrypoint.d/30-inject-sentry-dsn.sh
RUN chmod +x /docker-entrypoint.d/30-inject-sentry-dsn.sh
