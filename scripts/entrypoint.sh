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
        echo '    "file" "../cstrike/addons/metamod/bin/linux64/server"' >> "$CSTRIKE_DIR/addons/metamod.vdf"
        echo '}' >> "$CSTRIKE_DIR/addons/metamod.vdf"
    fi

    # Initialize maps folder if empty
    if [ -d "$CSTRIKE_DIR/maps" ] && [ -z "$(ls -A $CSTRIKE_DIR/maps 2>/dev/null)" ]; then
        log_info "Initializing maps/ with defaults..."
        cp -r "$BACKUP_DIR/maps/"* "$CSTRIKE_DIR/maps/" 2>/dev/null || true
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
# Only writes settings that are explicitly set - doesn't override server.cfg with defaults
generate_env_config() {
    log_section "Generating Configuration"

    local cfg_file="/home/steam/css/cstrike/cfg/env_settings.cfg"

    cat > "$cfg_file" << EOF
// ============================================
// AUTO-GENERATED FROM ENVIRONMENT VARIABLES
// DO NOT EDIT - Changes will be overwritten on restart
// ============================================
// Generated at: $(date)
// Only explicitly set env vars are included here.
// Base settings come from server.cfg

EOF

    # Server Identity (always set hostname)
    echo "// === Server Identity ===" >> "$cfg_file"
    echo "hostname \"${CSS_HOSTNAME:-Counter-Strike Source Server}\"" >> "$cfg_file"
    [ -n "$CSS_CONTACT" ] && echo "sv_contact \"$CSS_CONTACT\"" >> "$cfg_file"
    [ -n "$CSS_REGION" ] && echo "sv_region $CSS_REGION" >> "$cfg_file"

    # Fast Download (critical for custom content)
    echo "" >> "$cfg_file"
    echo "// === Fast Download ===" >> "$cfg_file"
    [ -n "$CSS_DOWNLOADURL" ] && echo "sv_downloadurl \"$CSS_DOWNLOADURL\"" >> "$cfg_file"
    [ -n "$CSS_MAXFILESIZE" ] && echo "net_maxfilesize $CSS_MAXFILESIZE" >> "$cfg_file"

    # Optional overrides - only if explicitly set
    local has_gameplay=0

    if [ -n "$CSS_FRIENDLYFIRE" ] || [ -n "$CSS_ALLTALK" ] || [ -n "$CSS_TIMELIMIT" ] || \
       [ -n "$CSS_ROUNDTIME" ] || [ -n "$CSS_FREEZETIME" ] || [ -n "$CSS_BUYTIME" ] || \
       [ -n "$CSS_STARTMONEY" ] || [ -n "$CSS_C4TIMER" ] || [ -n "$CSS_MAXROUNDS" ] || \
       [ -n "$CSS_WINLIMIT" ] || [ -n "$CSS_GRAVITY" ] || [ -n "$CSS_FALLDAMAGE" ]; then
        echo "" >> "$cfg_file"
        echo "// === Gameplay Overrides ===" >> "$cfg_file"
        has_gameplay=1
    fi

    [ -n "$CSS_FRIENDLYFIRE" ] && echo "mp_friendlyfire $CSS_FRIENDLYFIRE" >> "$cfg_file"
    [ -n "$CSS_ALLTALK" ] && echo "sv_alltalk $CSS_ALLTALK" >> "$cfg_file"
    [ -n "$CSS_TIMELIMIT" ] && echo "mp_timelimit $CSS_TIMELIMIT" >> "$cfg_file"
    [ -n "$CSS_ROUNDTIME" ] && echo "mp_roundtime $CSS_ROUNDTIME" >> "$cfg_file"
    [ -n "$CSS_FREEZETIME" ] && echo "mp_freezetime $CSS_FREEZETIME" >> "$cfg_file"
    [ -n "$CSS_BUYTIME" ] && echo "mp_buytime $CSS_BUYTIME" >> "$cfg_file"
    [ -n "$CSS_STARTMONEY" ] && echo "mp_startmoney $CSS_STARTMONEY" >> "$cfg_file"
    [ -n "$CSS_C4TIMER" ] && echo "mp_c4timer $CSS_C4TIMER" >> "$cfg_file"
    [ -n "$CSS_MAXROUNDS" ] && echo "mp_maxrounds $CSS_MAXROUNDS" >> "$cfg_file"
    [ -n "$CSS_WINLIMIT" ] && echo "mp_winlimit $CSS_WINLIMIT" >> "$cfg_file"
    [ -n "$CSS_GRAVITY" ] && echo "sv_gravity $CSS_GRAVITY" >> "$cfg_file"
    [ -n "$CSS_FALLDAMAGE" ] && echo "mp_falldamage $CSS_FALLDAMAGE" >> "$cfg_file"

    # Bot settings - only if explicitly set
    if [ -n "$CSS_BOT_QUOTA" ] || [ -n "$CSS_BOT_QUOTA_MODE" ] || [ -n "$CSS_BOT_DIFFICULTY" ]; then
        echo "" >> "$cfg_file"
        echo "// === Bot Configuration ===" >> "$cfg_file"
    fi

    [ -n "$CSS_BOT_QUOTA" ] && echo "bot_quota $CSS_BOT_QUOTA" >> "$cfg_file"
    [ -n "$CSS_BOT_QUOTA_MODE" ] && echo "bot_quota_mode \"$CSS_BOT_QUOTA_MODE\"" >> "$cfg_file"
    [ -n "$CSS_BOT_DIFFICULTY" ] && echo "bot_difficulty $CSS_BOT_DIFFICULTY" >> "$cfg_file"
    [ -n "$CSS_BOT_CHATTER" ] && echo "bot_chatter \"$CSS_BOT_CHATTER\"" >> "$cfg_file"
    [ -n "$CSS_BOT_JOIN_AFTER_PLAYER" ] && echo "bot_join_after_player $CSS_BOT_JOIN_AFTER_PLAYER" >> "$cfg_file"
    [ -n "$CSS_BOT_AUTO_VACATE" ] && echo "bot_auto_vacate $CSS_BOT_AUTO_VACATE" >> "$cfg_file"
    [ -n "$CSS_BOT_PREFIX" ] && echo "bot_prefix \"$CSS_BOT_PREFIX\"" >> "$cfg_file"

    # Security settings - only if explicitly set
    if [ -n "$CSS_PURE" ] || [ -n "$CSS_CHEATS" ] || [ -n "$CSS_ALLOWUPLOAD" ] || [ -n "$CSS_ALLOWDOWNLOAD" ]; then
        echo "" >> "$cfg_file"
        echo "// === Security Overrides ===" >> "$cfg_file"
    fi

    [ -n "$CSS_PURE" ] && echo "sv_pure $CSS_PURE" >> "$cfg_file"
    [ -n "$CSS_CHEATS" ] && echo "sv_cheats $CSS_CHEATS" >> "$cfg_file"
    [ -n "$CSS_ALLOWUPLOAD" ] && echo "sv_allowupload $CSS_ALLOWUPLOAD" >> "$cfg_file"
    [ -n "$CSS_ALLOWDOWNLOAD" ] && echo "sv_allowdownload $CSS_ALLOWDOWNLOAD" >> "$cfg_file"

    # Logging - only if explicitly set
    if [ -n "$CSS_LOG" ] || [ -n "$CSS_LOGBANS" ] || [ -n "$CSS_LOGDETAIL" ]; then
        echo "" >> "$cfg_file"
        echo "// === Logging Overrides ===" >> "$cfg_file"
    fi

    [ -n "$CSS_LOG" ] && echo "log $CSS_LOG" >> "$cfg_file"
    [ -n "$CSS_LOGBANS" ] && echo "sv_logbans $CSS_LOGBANS" >> "$cfg_file"
    [ -n "$CSS_LOGDETAIL" ] && echo "mp_logdetail $CSS_LOGDETAIL" >> "$cfg_file"

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
    log_info "Launching srcds_run_64 (64-bit)..."
    echo ""

    # Change to server directory and start
    cd /home/steam/css

    exec ./srcds_run_64 \
        -game cstrike \
        +hostname "${CSS_HOSTNAME:-Counter-Strike Source Server}" \
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
