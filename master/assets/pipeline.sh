#!/bin/sh
set -e

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1382002361903349911/DEpHB2rlHCEDhs3rlN0nef1eJreMzKTkd0z3jfbHsoDmqQimY-mYUWQuwn3rD9yOMx9N"

if [ -z "$DISCORD_WEBHOOK_URL" ]; then
  echo "❌ DISCORD_WEBHOOK_URL not set"
  exit 1
fi

# Helper function: send success message to Discord
send_discord_success() {
  curl -H "Content-Type: application/json" \
    -X POST \
    -d "{
      \"embeds\": [{
        \"title\": \"✅ Courriel Deployed Successfully\",
        \"description\": \"Image: \`p4ul/courriel:latest\`\nHost: \`$(hostname)\`\",
        \"color\": 3066993
      }]
    }" "$DISCORD_WEBHOOK_URL" || echo "⚠️ Discord success notification failed"
}

# Helper function: send failure message to Discord
send_discord_failure() {
  local reason="$1"
  curl -H "Content-Type: application/json" \
    -X POST \
    -d "{
      \"embeds\": [{
        \"title\": \"❌ Courriel Deployment Failed\",
        \"description\": \"${reason}\nHost: \`$(hostname)\`\",
        \"color\": 15158332
      }]
    }" "$DISCORD_WEBHOOK_URL" || echo "⚠️ Discord failure notification failed"
}

echo "📥 Cloning repository..."
git clone https://github.com/P4UL-M/Courriel.git /courriel
cd /courriel

# Create .env.local file if it doesn't exist
if [ ! -f .env.local ]; then
  echo "Creating .env.local file..."
  cat <<EOF > .env.local
    # Courriel environment variables
    GOOGLE_CLIENT_ID=my-google-client-id.apps.googleusercontent.com
    GOOGLE_CLIENT_SECRET=my-google-client-secret
    MICROSOFT_ENTRA_ID_CLIENT_ID=my-microsoft-client-id
    MICROSOFT_ENTRA_ID_CLIENT_SECRET=my-microsoft-client-secret
    NEXTAUTH_URL=http://localhost:3000
    NEXTAUTH_SECRET="my-nextauth-secret"
EOF
fi

echo "🔧 Building Docker image..."
docker build -t courriel-app .

echo "🔗 Creating Docker network..."
docker network create courriel-net || true

echo "🚀 Running app container for test..."
docker run -d \
  --name test-app \
  --network courriel-net \
  -p 3001:3000 \
  --env-file .env.local \
  -e AUTH_TRUST_HOST=true \
  courriel-app

# Give the app time to start
echo "⏳ Waiting for app to initialize..."
sleep 5

echo "✅ Running health check..."
if curl -s http://host.docker.internal:3001/api/healthcheck; then
    echo "\n✅ App is healthy!"
else
    echo "❌ App failed health check. Logs:"
    docker logs test-app || true

    send_discord_failure "Health check failed for test container. See logs below."

    echo "🧹 Cleaning up test container and network..."
    docker stop test-app && docker rm test-app
    docker network rm courriel-net || true
    exit 1
fi

echo "🧹 Cleaning up..."
docker stop test-app && docker rm test-app
docker network rm courriel-net || true

echo "🏷️ Tagging image..."
docker tag courriel-app p4ul/courriel:latest

# Production deployment
PROD_CONTAINER_NAME=courriel-prod
echo "🔄 Checking for existing production container..."
if docker ps -q -f name=$PROD_CONTAINER_NAME; then
    echo "✅ Found existing production container: $PROD_CONTAINER_NAME"
    echo "♻️ Stopping existing production container..."
    docker stop $PROD_CONTAINER_NAME 2>/dev/null || true
    docker rm $PROD_CONTAINER_NAME 2>/dev/null || true
else
    echo "❌ No existing production container found."
fi


echo "🚀 Starting new production container..."
docker run -d \
    --name $PROD_CONTAINER_NAME \
    -p 3000:3000 \
    --env-file .env.local \
    -e AUTH_TRUST_HOST=true \
    p4ul/courriel:latest

echo "✅ Production deployed successfully!"

echo "📢 Sending Discord notification..."
send_discord_success || send_discord_failure "Failed to send Discord notification"
if [ $? -ne 0 ]; then
    echo "❌ Failed to send Discord notification."
    exit 1
fi

echo "✅ Discord notification sent!"

echo "🎉 Pipeline completed successfully."