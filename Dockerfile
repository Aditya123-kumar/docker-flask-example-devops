###############################################################################
# Assets
###############################################################################

FROM node:24.20.0-trixie-slim AS assets

WORKDIR /app/assets

ENV NODE_ENV="production"

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
    && apt-get clean

COPY --chown=node:node assets/package.json assets/*yarn* ./

RUN yarn install && yarn cache clean

COPY --chown=node:node . ..

RUN sed -i 's/\r$//' ../run \
    && chmod +x ../run \
    && if [ "${NODE_ENV}" != "development" ]; then \
    ../run yarn:build:js && ../run yarn:build:css; \
    else \
    mkdir -p /app/public; \
    fi

CMD ["bash"]


###############################################################################
# Application build
###############################################################################

FROM python:3.14.7-slim-trixie AS app-build

WORKDIR /app

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

RUN chmod 0755 bin/* && bin/uv-install


###############################################################################
# Application
###############################################################################

FROM python:3.14.7-slim-trixie AS app

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/home/python/.local/bin:${PATH}"

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

ENTRYPOINT ["/app/bin/docker-entrypoint-web"]