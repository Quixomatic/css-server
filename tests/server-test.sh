#!/bin/bash
# ============================================
# Counter-Strike: Source Server Test Suite
# ============================================
# Run this to verify server installation is correct.
# Usage: ./tests/server-test.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARN_COUNT++))
}

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║       Counter-Strike: Source Server Test Suite            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Server binary exists
echo "=== Core Server Tests ==="
if [ -f "/home/steam/css/srcds_run" ]; then
    pass "srcds_run found"
else
    fail "srcds_run not found - server not installed"
fi

if [ -f "/home/steam/css/srcds_linux" ]; then
    pass "srcds_linux binary found"
else
    fail "srcds_linux binary not found"
fi

# Test 2: Game directory exists
if [ -d "/home/steam/css/cstrike" ]; then
    pass "cstrike game directory exists"
else
    fail "cstrike directory not found"
fi

# Test 3: User check
echo ""
echo "=== Security Tests ==="
if [ "$(whoami)" != "root" ]; then
    pass "Not running as root (running as: $(whoami))"
else
    fail "Running as root - this is a security risk"
fi

# Test 4: MetaMod installation
echo ""
echo "=== MetaMod Tests ==="
if [ -d "/home/steam/css/cstrike/addons/metamod" ]; then
    pass "MetaMod directory exists"
else
    fail "MetaMod not installed"
fi

if [ -f "/home/steam/css/cstrike/addons/metamod.vdf" ]; then
    pass "metamod.vdf loader file exists"
else
    fail "metamod.vdf not found - MetaMod won't load"
fi

if [ -f "/home/steam/css/cstrike/addons/metamod/bin/server.so" ]; then
    pass "MetaMod server.so binary found"
else
    warn "MetaMod server.so not found (might be named differently)"
fi

# Test 5: SourceMod installation
echo ""
echo "=== SourceMod Tests ==="
if [ -d "/home/steam/css/cstrike/addons/sourcemod" ]; then
    pass "SourceMod directory exists"
else
    fail "SourceMod not installed"
fi

if [ -d "/home/steam/css/cstrike/addons/sourcemod/plugins" ]; then
    PLUGIN_COUNT=$(find /home/steam/css/cstrike/addons/sourcemod/plugins -name "*.smx" -type f 2>/dev/null | wc -l)
    pass "SourceMod plugins directory exists ($PLUGIN_COUNT plugins found)"
else
    fail "SourceMod plugins directory not found"
fi

if [ -d "/home/steam/css/cstrike/addons/sourcemod/configs" ]; then
    pass "SourceMod configs directory exists"
else
    fail "SourceMod configs directory not found"
fi

if [ -f "/home/steam/css/cstrike/addons/sourcemod/configs/admins_simple.ini" ]; then
    pass "admins_simple.ini exists"
else
    warn "admins_simple.ini not found - no admins configured"
fi

# Test 6: Configuration files
echo ""
echo "=== Configuration Tests ==="
if [ -f "/home/steam/css/cstrike/cfg/server.cfg" ]; then
    pass "server.cfg exists"
else
    fail "server.cfg not found"
fi

if [ -f "/home/steam/css/cstrike/cfg/mapcycle.txt" ]; then
    MAP_COUNT=$(wc -l < /home/steam/css/cstrike/cfg/mapcycle.txt 2>/dev/null || echo "0")
    pass "mapcycle.txt exists ($MAP_COUNT maps)"
else
    warn "mapcycle.txt not found"
fi

if [ -f "/home/steam/css/cstrike/cfg/motd.txt" ]; then
    pass "motd.txt exists"
else
    warn "motd.txt not found"
fi

# Test 7: Maps
echo ""
echo "=== Map Tests ==="
if [ -d "/home/steam/css/cstrike/maps" ]; then
    BSP_COUNT=$(find /home/steam/css/cstrike/maps -name "*.bsp" -type f 2>/dev/null | wc -l)
    pass "Maps directory exists ($BSP_COUNT .bsp files)"
else
    fail "Maps directory not found"
fi

if [ -f "/home/steam/css/cstrike/maps/de_dust2.bsp" ]; then
    pass "de_dust2.bsp exists (default map)"
else
    warn "de_dust2.bsp not found - default map may fail to load"
fi

# Test 8: Steam SDK
echo ""
echo "=== Steam SDK Tests ==="
if [ -L "/home/steam/.steam/sdk32/steamclient.so" ] || [ -f "/home/steam/.steam/sdk32/steamclient.so" ]; then
    pass "Steam SDK32 symlink exists"
else
    warn "Steam SDK32 symlink missing - may cause startup warnings"
fi

# Test 9: Write permissions
echo ""
echo "=== Permission Tests ==="
if [ -w "/home/steam/css/cstrike/cfg" ]; then
    pass "Config directory is writable"
else
    fail "Config directory is not writable"
fi

if [ -w "/home/steam/css/cstrike/addons/sourcemod/logs" ]; then
    pass "SourceMod logs directory is writable"
else
    warn "SourceMod logs directory is not writable"
fi

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                      Test Summary                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASS_COUNT"
echo -e "  ${RED}Failed:${NC}   $FAIL_COUNT"
echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Some tests failed. Server may not work correctly.${NC}"
    exit 1
else
    echo -e "${GREEN}All critical tests passed!${NC}"
    if [ $WARN_COUNT -gt 0 ]; then
        echo -e "${YELLOW}Some warnings were generated - review above.${NC}"
    fi
    exit 0
fi
