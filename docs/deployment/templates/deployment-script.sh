#!/bin/bash

# Realms Deployment Script
# This script is executed by GitHub Actions to deploy new versions

set -e  # Exit on any error

# Configuration
APP_DIR="/opt/realms/app"
ENV_FILE="/etc/realms/env"
LOG_FILE="/var/log/realms/deploy.log"
SERVICE_NAME="realms"

# Logging function
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
  log "ERROR: $1"
  exit 1
}

# Start deployment
log "========================================="
log "Starting deployment"
log "========================================="

# Load environment variables
if [ ! -f "$ENV_FILE" ]; then
  error_exit "Environment file not found at $ENV_FILE"
fi

log "Loading environment variables from $ENV_FILE"
set -a
# shellcheck source=/etc/realms/env
source "$ENV_FILE"
set +a

# Navigate to application directory
cd "$APP_DIR" || error_exit "Failed to navigate to $APP_DIR"

# Pull latest code
log "Pulling latest code from origin/main"
git fetch origin || error_exit "Git fetch failed"
git reset --hard origin/main || error_exit "Git reset failed"

# Get current commit
COMMIT_HASH=$(git rev-parse --short HEAD)
log "Deploying commit: $COMMIT_HASH"

# Install/update dependencies
log "Installing dependencies"
mix deps.get --only prod || error_exit "Failed to get dependencies"

# Compile application
log "Compiling application"
mix compile || error_exit "Compilation failed"

# Deploy assets
log "Deploying assets"
mix assets.deploy || error_exit "Asset deployment failed"

# Build release
log "Building release"
mix release --overwrite || error_exit "Release build failed"

# Run migrations using release binary
log "Running database migrations"
_build/prod/rel/realms/bin/realms eval "Realms.Release.migrate()" || error_exit "Database migration failed"

# Restart service
log "Restarting $SERVICE_NAME service"
sudo systemctl restart "$SERVICE_NAME" || error_exit "Failed to restart service"

# Wait for service to start
log "Waiting for service to start (5 seconds)"
sleep 5

# Health check
log "Performing health check"
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
  log "Service is running"

  # Check if app responds on localhost
  if curl -f http://localhost:${PORT:-4000} > /dev/null 2>&1; then
    log "Health check passed: Application is responding"
  else
    log "WARNING: Service is running but application is not responding on port ${PORT:-4000}"
    log "Recent logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager | tee -a "$LOG_FILE"
  fi
else
  log "Service failed to start. Recent logs:"
  sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager | tee -a "$LOG_FILE"
  error_exit "Service failed to start"
fi

# Success
log "========================================="
log "Deployment completed successfully"
log "Commit: $COMMIT_HASH"
log "========================================="

exit 0
