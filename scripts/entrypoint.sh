#!/bin/bash
# Counter-Strike: Source Server Entrypoint
# Handles first-run initialization, configuration generation, and server startup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Handle update request
if [ "$1" == "update" ]; then
    log_info "Updating Counter-Strike: Source..."
    /home/steam/steamcmd/steamcmd.sh \
        +force_install_dir /home/steam/css \
        +login anonymous \
        +app_update 232330 validate \
        +quit
    log_info "Update complete!"
    exit 0
fi

# Handle shell request
if [ "$1" == "bash" ] || [ "$1" == "sh" ]; then
    exec /bin/bash
fi

# ============================================
# FIRST-RUN INITIALIZATION
# ============================================
# When volumes are mounted but empty, copy defaults from the image backup

initialize_volumes() {
    log_section "Checking Volumes"

    # Define source (backup) and target directories
    local BACKUP_DIR="/home/steam/css-defaults"
    local CSTRIKE_DIR="/home/steam/css/cstrike"

    # Check if this is first run (backup doesn't exist yet means fresh container)
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "First container start - creating backup of default files..."
        mkdir -p "$BACKUP_DIR"

        # Backup default configs if they exist
        [ -d "$CSTRIKE_DIR/cfg" ] && cp -r "$CSTRIKE_DIR/cfg" "$BACKUP_DIR/"
        [ -d "$CSTRIKE_DIR/addons" ] && cp -r "$CSTRIKE_DIR/addons" "$BACKUP_DIR/"

        log_info "Backup created at $BACKUP_DIR"
    fi

    # Initialize empty mounted volumes with defaults

    # CFG directory
    if [ -d "$CSTRIKE_DIR/cfg" ] && [ -z "$(ls -A $CSTRIKE_DIR/cfg 2>/dev/null)" ]; then
        log_info "Initializing cfg/ with defaults..."
        cp -r "$BACKUP_DIR/cfg/"* "$CSTRIKE_DIR/cfg/" 2>/dev/null || true
    fi

    # ADDONS directory (entire folder mounted)
    if [ -d "$CSTRIKE_DIR/addons" ] && [ -z "$(ls -A $CSTRIKE_DIR/addons 2>/dev/null)" ]; then
        log_info "Initializing addons/ with defaults (MetaMod + SourceMod)..."
        cp -r "$BACKUP_DIR/addons/"* "$CSTRIKE_DIR/addons/" 2>/dev/null || true
    fi

    # If addons exists but sourcemod subfolder is empty (granular mount)
    if [ -d "$CSTRIKE_DIR/addons/sourcemod" ]; then
        # SourceMod plugins
        if [ -d "$CSTRIKE_DIR/addons/sourcemod/plugins" ] && [ -z "$(ls -A $CSTRIKE_DIR/addons/sourcemod/plugins 2>/dev/null)" ]; then
            log_info "Initializing sourcemod/plugins/ with defaults..."
            cp -r "$BACKUP_DIR/addons/sourcemod/plugins/"* "$CSTRIKE_DIR/addons/sourcemod/plugins/" 2>/dev/null || true
        fi

        # SourceMod configs
        if [ -d "$CSTRIKE_DIR/addons/sourcemod/configs" ] && [ -z "$(ls -A $CSTRIKE_DIR/addons/sourcemod/configs 2>/dev/null)" ]; then
            log_info "Initializing sourcemod/configs/ with defaults..."
            cp -r "$BACKUP_DIR/addons/sourcemod/configs/"* "$CSTRIKE_DIR/addons/sourcemod/configs/" 2>/dev/null || true
        fi

        # SourceMod data
        if [ -d "$CSTRIKE_DIR/addons/sourcemod/data" ] && [ -z "$(ls -A $CSTRIKE_DIR/addons/sourcemod/data 2>/dev/null)" ]; then
            log_info "Initializing sourcemod/data/ with defaults..."
            cp -r "$BACKUP_DIR/addons/sourcemod/data/"* "$CSTRIKE_DIR/addons/sourcemod/data/" 2>/dev/null || true
        fi

        # SourceMod translations
        if [ -d "$CSTRIKE_DIR/addons/sourcemod/translations" ] && [ -z "$(ls -A $CSTRIKE_DIR/addons/sourcemod/translations 2>/dev/null)" ]; then
            log_info "Initializing sourcemod/translations/ with defaults..."
            cp -r "$BACKUP_DIR/addons/sourcemod/translations/"* "$CSTRIKE_DIR/addons/sourcemod/translations/" 2>/dev/null || true
        fi

        # SourceMod scripting
        if [ -d "$CSTRIKE_DIR/addons/sourcemod/scripting" ] && [ -z "$(ls -A $CSTRIKE_DIR/addons/sourcemod/scripting 2>/dev/null)" ]; then
            log_info "Initializing sourcemod/scripting/ with defaults..."
            cp -r "$BACKUP_DIR/addons/sourcemod/scripting/"* "$CSTRIKE_DIR/addons/sourcemod/scripting/" 2>/dev/null || true
        fi
    fi

    # Ensure metamod.vdf exists (critical for plugin loading)
    if [ ! -f "$CSTRIKE_DIR/addons/metamod.vdf" ]; then
        log_info "Creating metamod.vdf loader..."
        mkdir -p "$CSTRIKE_DIR/addons"
        echo '"Plugin"' > "$CSTRIKE_DIR/addons/metamod.vdf"
        echo '{' >> "$CSTRIKE_DIR/addons/metamod.vdf"
        echo '    "file" "../cstrike/addons/metamod/bin/linux32/server"' >> "$CSTRIKE_DIR/addons/metamod.vdf"
        echo '}' >> "$CSTRIKE_DIR/addons/metamod.vdf"
    fi

    # Create empty directories if they don't exist (for mounts)
    mkdir -p "$CSTRIKE_DIR/maps" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/sound" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/materials" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/models" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/particles" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/download" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/logs" 2>/dev/null || true
    mkdir -p "$CSTRIKE_DIR/addons/sourcemod/logs" 2>/dev/null || true

    log_info "Volume initialization complete"
}

# Generate dynamic configuration from environment variables
generate_env_config() {
    log_section "Generating Configuration"

    cat > /home/steam/css/cstrike/cfg/env_settings.cfg << EOF
// ============================================
// AUTO-GENERATED FROM ENVIRONMENT VARIABLES
// DO NOT EDIT - Changes will be overwritten on restart
// ============================================
// Generated at: $(date)

// === Server Identity ===
hostname "${CSS_HOSTNAME:-Counter-Strike Source Server}"
sv_contact "${CSS_CONTACT:-}"
sv_region ${CSS_REGION:-255}

// === Network Settings ===
sv_maxrate ${CSS_MAXRATE:-0}
sv_minrate ${CSS_MINRATE:-20000}
sv_maxupdaterate ${CSS_MAXUPDATERATE:-100}
sv_minupdaterate ${CSS_MINUPDATERATE:-30}
sv_maxcmdrate ${CSS_MAXUPDATERATE:-100}
sv_mincmdrate ${CSS_MINUPDATERATE:-30}

// === Gameplay Settings ===
mp_friendlyfire ${CSS_FRIENDLYFIRE:-0}
sv_alltalk ${CSS_ALLTALK:-0}
mp_timelimit ${CSS_TIMELIMIT:-30}
mp_roundtime ${CSS_ROUNDTIME:-2.5}
mp_freezetime ${CSS_FREEZETIME:-6}
mp_buytime ${CSS_BUYTIME:-90}
mp_startmoney ${CSS_STARTMONEY:-800}
mp_c4timer ${CSS_C4TIMER:-45}
mp_maxrounds ${CSS_MAXROUNDS:-0}
mp_winlimit ${CSS_WINLIMIT:-0}
sv_gravity ${CSS_GRAVITY:-800}
mp_falldamage ${CSS_FALLDAMAGE:-1}

// === Bot Configuration ===
bot_quota ${CSS_BOT_QUOTA:-0}
bot_quota_mode "${CSS_BOT_QUOTA_MODE:-fill}"
bot_difficulty ${CSS_BOT_DIFFICULTY:-2}
bot_chatter "${CSS_BOT_CHATTER:-minimal}"
bot_join_after_player ${CSS_BOT_JOIN_AFTER_PLAYER:-1}
bot_auto_vacate ${CSS_BOT_AUTO_VACATE:-1}
bot_prefix "${CSS_BOT_PREFIX:-[BOT]}"

// === Security Settings ===
sv_pure ${CSS_PURE:-2}
sv_cheats ${CSS_CHEATS:-0}
sv_allowupload ${CSS_ALLOWUPLOAD:-0}
sv_allowdownload ${CSS_ALLOWDOWNLOAD:-1}
sv_rcon_banpenalty ${CSS_RCON_BANPENALTY:-30}
sv_rcon_maxfailures ${CSS_RCON_MAXFAILURES:-10}
sv_rcon_minfailures 5
sv_rcon_minfailuretime 30

// === Fast Download ===
sv_downloadurl "${CSS_DOWNLOADURL:-}"
net_maxfilesize ${CSS_MAXFILESIZE:-64}

// === Logging ===
log ${CSS_LOG:-on}
sv_logbans ${CSS_LOGBANS:-1}
sv_logecho 1
sv_logfile 1
sv_log_onefile 0
mp_logdetail ${CSS_LOGDETAIL:-3}
EOF

    log_info "Generated env_settings.cfg"
}

# Create my-server.cfg if it doesn't exist
ensure_custom_config() {
    local cfg_file="/home/steam/css/cstrike/cfg/my-server.cfg"
    if [ ! -f "$cfg_file" ]; then
        cat > "$cfg_file" << 'EOF'
// ============================================
// Custom Server Configuration
// ============================================
// Add your custom settings here.
// This file persists across container restarts.
//
// Example:
// mp_autoteambalance 1
// sv_alltalk 1
EOF
        log_info "Created my-server.cfg template"
    fi
}

# Ensure ban files exist
ensure_ban_files() {
    touch /home/steam/css/cstrike/cfg/banned_user.cfg 2>/dev/null || true
    touch /home/steam/css/cstrike/cfg/banned_ip.cfg 2>/dev/null || true
}

# Verify installation
verify_installation() {
    log_section "Verifying Installation"

    local errors=0

    if [ ! -f "/home/steam/css/srcds_run" ]; then
        log_error "srcds_run not found!"
        errors=$((errors + 1))
    else
        log_info "srcds_run: OK"
    fi

    if [ ! -d "/home/steam/css/cstrike/addons/metamod" ]; then
        log_warn "MetaMod not found - plugins may not work"
    else
        log_info "MetaMod: OK"
    fi

    if [ ! -d "/home/steam/css/cstrike/addons/sourcemod" ]; then
        log_warn "SourceMod not found - admin features may not work"
    else
        log_info "SourceMod: OK"
    fi

    if [ $errors -gt 0 ]; then
        log_error "Installation verification failed!"
        exit 1
    fi
}

# Print startup banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Counter-Strike: Source Dedicated Server           ║${NC}"
    echo -e "${CYAN}║              with MetaMod + SourceMod                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Hostname:    ${CSS_HOSTNAME:-Counter-Strike Source Server}"
    echo "  Map:         ${CSS_MAP:-de_dust2}"
    echo "  Max Players: ${CSS_MAXPLAYERS:-24}"
    echo "  Tickrate:    ${CSS_TICKRATE:-66}"
    echo "  Port:        ${CSS_PORT:-27015}"
    echo "  Bots:        ${CSS_BOT_QUOTA:-0} (${CSS_BOT_QUOTA_MODE:-fill} mode)"
    echo ""
    if [ -n "$STEAM_GSLT" ]; then
        echo -e "  GSLT:        ${GREEN}Configured (public server)${NC}"
    else
        echo -e "  GSLT:        ${YELLOW}Not set (LAN mode only)${NC}"
    fi
    echo ""
}

# Main startup sequence
main() {
    print_banner
    initialize_volumes
    verify_installation
    ensure_ban_files
    ensure_custom_config
    generate_env_config

    log_section "Starting Server"

    # Build server arguments
    SERVER_ARGS=""

    # Add GSLT if provided (required for public servers)
    if [ -n "$STEAM_GSLT" ]; then
        SERVER_ARGS="$SERVER_ARGS +sv_setsteamaccount $STEAM_GSLT"
        log_info "Steam Game Server Login Token configured"
    else
        log_warn "No STEAM_GSLT set - server will run in LAN mode only"
        SERVER_ARGS="$SERVER_ARGS +sv_lan 1"
    fi

    if [ -n "$CSS_PASSWORD" ]; then
        log_info "Server password is set"
    fi

    if [ -z "$RCON_PASSWORD" ]; then
        log_warn "No RCON_PASSWORD set - RCON will be disabled"
    else
        log_info "RCON password is set"
    fi

    echo ""
    log_info "Launching srcds_run..."
    echo ""

    # Change to server directory and start
    cd /home/steam/css

    exec ./srcds_run \
        -game cstrike \
        -port "${CSS_PORT:-27015}" \
        +map "${CSS_MAP:-de_dust2}" \
        +maxplayers "${CSS_MAXPLAYERS:-24}" \
        -tickrate "${CSS_TICKRATE:-66}" \
        +sv_password "${CSS_PASSWORD:-}" \
        +rcon_password "${RCON_PASSWORD:-}" \
        +exec server.cfg \
        +exec env_settings.cfg \
        +exec my-server.cfg \
        -norestart \
        $SERVER_ARGS \
        "$@"
}

# Run main function
main "$@"
