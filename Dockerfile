###############################################################################
# Assets
###############################################################################

FROM node:24.20.0-trixie-slim AS assets

WORKDIR /app/assets

ENV NODE_ENV=production

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
    && apt-get clean

COPY --chown=node:node assets/package.json assets/*yarn* ./

RUN yarn install && yarn cache clean

COPY --chown=node:node . ..

RUN mkdir -p /app/public/js /app/public/css \
    && node esbuild.config.mjs \
    && npm exec --yes --package=@tailwindcss/cli@4.3.3 -- \
       tailwindcss -i css/app.css -o ../public/css/app.css --minify


###############################################################################
# Application build
###############################################################################

FROM python:3.14.7-slim-trixie AS app-build

WORKDIR /app

ENV UV_PROJECT_ENVIRONMENT=/home/python/.local

# Create application user
RUN groupadd --system python \
    && useradd --system --gid python --create-home --home-dir /home/python python

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       curl \
       libpq-dev \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
    && apt-get clean

COPY --from=ghcr.io/astral-sh/uv:0.8.17 /uv /uvx /usr/local/bin/

COPY --chown=python:python pyproject.toml uv.lock* ./

COPY --chown=python:python bin/ ./bin

RUN chmod 0755 bin/* \
    && bin/uv-install


###############################################################################
# Application
###############################################################################

FROM python:3.14.7-slim-trixie AS app

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/home/python/.local/bin:${PATH}"

# Create application user
RUN groupadd --system python \
    && useradd --system --gid python --create-home --home-dir /home/python python

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       libpq-dev \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
    && apt-get clean

COPY --chown=python:python --from=assets /app/public /public

COPY --chown=python:python --from=app-build /home/python/.local /home/python/.local

COPY --from=app-build /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

COPY --chown=python:python . .

RUN if [ "${FLASK_DEBUG}" != "true" ]; then \
    chmod +x bin/*; \
    fi

USER python

ENTRYPOINT ["/app/bin/docker-entrypoint-web"]