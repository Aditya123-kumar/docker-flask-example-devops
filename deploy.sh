#!/bin/bash

set -e

COMPOSE_FILE="docker-compose.prod.yml"
PROJECT_NAME="flask-prod"
NGINX_CONFIG="nginx/prod.conf"
STATE_FILE=".active_color"

dc() {
  docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@"
}
if [ -z "$APP_IMAGE" ]; then
  echo "ERROR: APP_IMAGE is not set."
  echo "Example: APP_IMAGE=localhost:5000/flask-app:test"
  exit 1
fi

echo "======================================"
echo " Zero Downtime Flask Deployment"
echo "======================================"
echo "Image: $APP_IMAGE"
echo ""

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

echo "[1/7] Starting PostgreSQL and Redis..."
dc up -d postgres redis

echo "[2/7] Pulling application image..."
dc pull "web-$NEW"

echo "[3/7] Starting $NEW version..."
dc up -d "web-$NEW"

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

if [ "$HEALTHY" != "true" ]; then
  echo ""
  echo "Health check FAILED!"
  echo "Rolling back..."

  dc stop "web-$NEW"
  dc rm -f "web-$NEW"

  exit 1
fi

echo "[5/7] Switching traffic to $NEW..."

sed -i "s/server web-$CURRENT:8000;/server web-$NEW:8000;/" "$NGINX_CONFIG"

dc up -d nginx

docker exec flask-nginx nginx -t
docker exec flask-nginx nginx -s reload

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

echo "[7/7] Removing old version..."

dc stop "web-$CURRENT"
dc rm -f "web-$CURRENT"

echo "$NEW" >"$STATE_FILE"

echo ""
echo "======================================"
echo " Deployment Successful!"
echo "======================================"
echo "Active version: $NEW"
echo "Image: $APP_IMAGE"
echo "Application: http://localhost:8081"
echo "======================================"