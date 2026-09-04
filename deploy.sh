#!/bin/bash

set -e

COMPOSE_FILE="docker-compose.prod.yml"
PROJECT_NAME="flask-prod"
NGINX_CONFIG="nginx/prod.conf"
STATE_FILE=".active_color"

COMPOSE="/c/Users/CEREBRENT PC/AppData/Local/Programs/DockerDesktop/resources/bin/docker-compose.exe"

dc() {
  "$COMPOSE" -p "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@"
}
echo "======================================"
echo " Zero Downtime Flask Deployment"
echo "======================================"

# --------------------------------------------------
# Detect current version
# --------------------------------------------------

if [ -f "$STATE_FILE" ]; then
  CURRENT=$(cat "$STATE_FILE")
else
  CURRENT="blue"
fi

if [ "$CURRENT" = "blue" ]; then
  NEW="green"
else
  NEW="blue"
fi

echo "Current version : $CURRENT"
echo "New version     : $NEW"
echo ""

# --------------------------------------------------
# Start infrastructure
# --------------------------------------------------

echo "[1/7] Starting PostgreSQL and Redis..."

dc up -d postgres redis

# --------------------------------------------------
# Build application
# --------------------------------------------------

echo "[2/7] Building application..."

dc build --no-cache "web-$NEW"

# --------------------------------------------------
# Start new version
# --------------------------------------------------

echo "[3/7] Starting $NEW version..."

dc up -d "web-$NEW"

# --------------------------------------------------
# Health check
# --------------------------------------------------

echo "[4/7] Waiting for $NEW to become healthy..."

HEALTHY=false

for i in {1..30}; do
  if dc exec -T "web-$NEW" \
    curl -fsS http://localhost:8000/up/ >/dev/null 2>&1; then

    HEALTHY=true
    echo "Health check: PASSED"
    break
  fi

  echo "Waiting... ($i/30)"
  sleep 2
done

# --------------------------------------------------
# Rollback if health check fails
# --------------------------------------------------

if [ "$HEALTHY" != "true" ]; then
  echo ""
  echo "Health check FAILED!"
  echo "Rolling back..."

  dc stop "web-$NEW"
  dc rm -f "web-$NEW"

  exit 1
fi

# --------------------------------------------------
# Switch Nginx traffic
# --------------------------------------------------

echo "[5/7] Switching traffic to $NEW..."

sed -i "s/server web-$CURRENT:8000;/server web-$NEW:8000;/" "$NGINX_CONFIG"

dc up -d nginx

docker exec flask-nginx nginx -t

docker exec flask-nginx nginx -s reload

# --------------------------------------------------
# Smoke test
# --------------------------------------------------

echo "[6/7] Testing application..."

sleep 2

if curl -fsS http://localhost:8081/up/ >/dev/null; then
  echo "Traffic switch: PASSED"
else
  echo "Traffic switch FAILED!"
  echo "Rolling back to $CURRENT..."

  sed -i "s/server web-$NEW:8000;/server web-$CURRENT:8000;/" "$NGINX_CONFIG"

  docker exec flask-nginx nginx -t
  docker exec flask-nginx nginx -s reload

  dc stop "web-$NEW"
  dc rm -f "web-$NEW"

  exit 1
fi

# --------------------------------------------------
# Cleanup old version
# --------------------------------------------------

echo "[7/7] Removing old version..."

dc stop "web-$CURRENT"
dc rm -f "web-$CURRENT"

echo "$NEW" >"$STATE_FILE"

echo ""
echo "======================================"
echo " Deployment Successful!"
echo "======================================"
echo "Active version: $NEW"
echo "Application: http://localhost:8081"
echo "======================================"
