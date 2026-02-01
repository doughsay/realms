#!/bin/bash

# Start a remote REPL session to connect to the running release

set -e

APP_NAME="realms"
RELEASE_PATH="_build/prod/rel/$APP_NAME"

if [ ! -f "$RELEASE_PATH/bin/$APP_NAME" ]; then
  echo "Error: Release not found at $RELEASE_PATH"
  echo "Please build the release first with: MIX_ENV=prod mix release"
  exit 1
fi

echo "Connecting to $APP_NAME release..."
"$RELEASE_PATH/bin/$APP_NAME" remote
