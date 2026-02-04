#!/bin/bash
# ============================================
# Install a SourceMod Plugin
# ============================================
# Usage: ./scripts/install-plugin.sh <plugin.smx> [container_name]
#
# Examples:
#   ./scripts/install-plugin.sh quake_sounds.smx
#   ./scripts/install-plugin.sh mapchooser_extended.smx css-server

set -e

PLUGIN_FILE="$1"
CONTAINER="${2:-css-server}"

if [ -z "$PLUGIN_FILE" ]; then
    echo "Usage: $0 <plugin.smx> [container_name]"
    echo ""
    echo "Examples:"
    echo "  $0 quake_sounds.smx"
    echo "  $0 ./downloads/mapchooser_extended.smx css-server"
    exit 1
fi

if [ ! -f "$PLUGIN_FILE" ]; then
    echo "Error: Plugin file not found: $PLUGIN_FILE"
    exit 1
fi

PLUGIN_NAME=$(basename "$PLUGIN_FILE")

echo "Installing plugin: $PLUGIN_NAME"
echo "Target container: $CONTAINER"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container '$CONTAINER' is not running"
    echo ""
    echo "Available containers:"
    docker ps --format '{{.Names}}'
    exit 1
fi

# Copy plugin to container
echo "Copying plugin to container..."
docker cp "$PLUGIN_FILE" "${CONTAINER}:/home/steam/css/cstrike/addons/sourcemod/plugins/"

# Refresh plugins
echo "Refreshing SourceMod plugins..."
docker exec -i "$CONTAINER" bash -c 'echo "sm plugins refresh" | /home/steam/css/srcds_run -game cstrike +quit' 2>/dev/null || true

echo ""
echo "Plugin installed: $PLUGIN_NAME"
echo ""
echo "To verify, run:"
echo "  docker exec -it $CONTAINER bash -c 'ls -la /home/steam/css/cstrike/addons/sourcemod/plugins/'"
echo ""
echo "Note: You may need to restart the server or use RCON to reload plugins:"
echo "  rcon sm plugins refresh"
