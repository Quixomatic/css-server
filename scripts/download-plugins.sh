#!/bin/bash
# ============================================
# Download MetaMod, SourceMod, and Plugins
# ============================================
# This script downloads the latest versions of MetaMod and SourceMod.
# Run this to update the mods/ directory with fresh downloads.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
METAMOD_VERSION="${METAMOD_VERSION:-1.12}"
SOURCEMOD_VERSION="${SOURCEMOD_VERSION:-1.12}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODS_DIR="$PROJECT_DIR/mods"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        MetaMod & SourceMod Download Script                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Create mods directory
mkdir -p "$MODS_DIR"

# Download MetaMod:Source
echo -e "${GREEN}=== Downloading MetaMod:Source ${METAMOD_VERSION} ===${NC}"
METAMOD_FILE=$(curl -sL "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/mmsource-latest-linux")
if [ -n "$METAMOD_FILE" ]; then
    echo "Latest version: $METAMOD_FILE"
    wget -q --show-progress -O "$MODS_DIR/metamod.tar.gz" \
        "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/${METAMOD_FILE}"
    echo -e "${GREEN}✓ MetaMod downloaded${NC}"
else
    echo -e "${RED}✗ Failed to get MetaMod version info${NC}"
    exit 1
fi

# Download SourceMod
echo ""
echo -e "${GREEN}=== Downloading SourceMod ${SOURCEMOD_VERSION} ===${NC}"
SM_FILE=$(curl -sL "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/sourcemod-latest-linux")
if [ -n "$SM_FILE" ]; then
    echo "Latest version: $SM_FILE"
    wget -q --show-progress -O "$MODS_DIR/sourcemod.tar.gz" \
        "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/${SM_FILE}"
    echo -e "${GREEN}✓ SourceMod downloaded${NC}"
else
    echo -e "${RED}✗ Failed to get SourceMod version info${NC}"
    exit 1
fi

# Summary
echo ""
echo -e "${CYAN}=== Download Complete ===${NC}"
echo ""
echo "Downloaded files:"
ls -lh "$MODS_DIR"/*.tar.gz 2>/dev/null || echo "No files found"
echo ""

# Plugin instructions
echo -e "${YELLOW}=== Additional Plugins ===${NC}"
echo ""
echo "The following popular plugins must be downloaded manually from AlliedModders:"
echo ""
echo "1. MapChooser Extended (map voting):"
echo "   https://forums.alliedmods.net/showthread.php?t=156974"
echo ""
echo "2. Quake Sounds (kill sounds):"
echo "   https://forums.alliedmods.net/showthread.php?t=224316"
echo ""
echo "3. Rock The Vote Extended:"
echo "   Usually included with MapChooser Extended"
echo ""
echo "4. GunGame (game mode):"
echo "   https://forums.alliedmods.net/showthread.php?t=93977"
echo ""
echo -e "Place downloaded ${CYAN}.smx${NC} files in:"
echo "  $PROJECT_DIR/dist/cstrike/addons/sourcemod/plugins/"
echo ""
echo "Or mount them via Docker volume to:"
echo "  /home/steam/css/cstrike/addons/sourcemod/plugins/"
echo ""

# Extraction instructions
echo -e "${YELLOW}=== To Install Manually ===${NC}"
echo ""
echo "Extract to your cstrike folder:"
echo "  tar -xzf $MODS_DIR/metamod.tar.gz -C /path/to/cstrike/"
echo "  tar -xzf $MODS_DIR/sourcemod.tar.gz -C /path/to/cstrike/"
echo ""
echo "Note: The Dockerfile automatically downloads and installs these during build."
echo ""
