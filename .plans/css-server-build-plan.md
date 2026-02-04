# Counter-Strike: Source Modern Docker Server Build Plan

## Executive Summary

Create a modern, feature-rich Counter-Strike: Source dedicated server Docker image combining:
- **Freeplay's** modern infrastructure, CI/CD, and security practices
- **Foxyserver's** comprehensive plugin setup and detailed game configuration

---

## Analysis: Best of Both Worlds

### From Freeplay (Modern Infrastructure)
| Feature | Why Include |
|---------|-------------|
| Modern base image (`lacledeslan/gamesvr-cssource` or fresh Ubuntu 22.04/24.04) | Security patches, modern libraries |
| Git submodules for SourceMod/MetaMod | Easy version management and updates |
| GitHub Actions CI/CD | Automated builds and testing |
| Comprehensive test suite | Ensures server health before deployment |
| `sv_pure 2` enforcement | Prevents client-side cheats |
| Fast download CDN support | Better player experience |
| Non-root user execution | Security best practice |
| Label schema for image metadata | Professional image organization |

### From Foxyserver (Rich Features)
| Feature | Why Include |
|---------|-------------|
| Quake Sounds plugin | Classic FPS audio feedback |
| MapChooser Extended | Player-driven map voting |
| Comprehensive bot configuration | Fills empty slots automatically |
| Detailed server.cfg | Fine-tuned gameplay settings |
| HTTP map download support (nginx) | Alternative to CDN |
| Update capability via entrypoint | Update game without rebuild |
| Environment variables for config | Runtime customization |
| mapcycle.txt with classic maps | Ready-to-play rotation |

---

## Component Versions (Latest as of 2024/2025)

Research and use the latest stable versions:

| Component | Target Version | Source |
|-----------|---------------|--------|
| Base OS | Ubuntu 22.04 LTS (Jammy) | Docker Hub |
| SteamCMD | Latest | media.steampowered.com |
| CS:S Dedicated Server | App ID 232330 | Steam |
| MetaMod:Source | 1.12.x or latest stable | [metamodsource.net](https://www.metamodsource.net/) |
| SourceMod | 1.12.x or latest stable | [sourcemod.net](https://www.sourcemod.net/) |
| MapChooser Extended | Latest | AlliedModders |
| Quake Sounds | Latest compatible | AlliedModders |
| Damage Report/Stats | Latest compatible | AlliedModders |

---

## Project Structure

```
css-server/
├── .github/
│   └── workflows/
│       ├── build-image.yml          # CI/CD pipeline
│       └── update-dockerhub.yml     # DockerHub publishing
├── .plans/
│   └── css-server-build-plan.md     # This plan
├── dist/
│   └── cstrike/
│       ├── cfg/
│       │   ├── server.cfg           # Main server config (foxyserver-style)
│       │   ├── autoexec.cfg         # Auto-execute config
│       │   ├── mapcycle.txt         # Map rotation
│       │   ├── motd.txt             # Message of the day
│       │   └── my-server.cfg        # Custom overrides (user-mounted)
│       ├── addons/
│       │   ├── metamod.vdf          # MetaMod loader
│       │   └── sourcemod/
│       │       ├── configs/         # Plugin configurations
│       │       ├── plugins/         # Active plugins (.smx)
│       │       └── translations/    # Language files
│       └── maps/                    # Custom maps (optional)
├── mods/                            # Plugin archives (downloaded during build)
│   └── .gitkeep
├── scripts/
│   ├── entrypoint.sh               # Container startup script
│   ├── update.sh                   # Game update script
│   └── download-plugins.sh         # Plugin download automation
├── tests/
│   └── server-test.sh              # Integration test suite
├── Dockerfile                       # Main build file
├── docker-compose.yml              # Easy deployment
├── Makefile                        # Build/run shortcuts
├── README.md                       # Documentation
└── .env.example                    # Environment variable template
```

---

## Phase 1: Base Infrastructure

### 1.1 Dockerfile Structure

```dockerfile
# escape=`
FROM ubuntu:22.04

LABEL maintainer="your-email@example.com"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.description="Counter-Strike: Source Dedicated Server"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN dpkg --add-architecture i386 && `
    apt-get update && `
    apt-get install -y `
        wget `
        ca-certificates `
        lib32gcc-s1 `
        lib32stdc++6 `
        lib32z1 `
        libncurses5:i386 `
        libbz2-1.0:i386 `
        libcurl4-gnutls-dev:i386 `
        unzip `
        curl `
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -d /home/steam steam
USER steam
WORKDIR /home/steam

# Install SteamCMD
RUN wget -qO- https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xvz

# Install CS:S Dedicated Server
RUN ./steamcmd.sh +force_install_dir ./css +login anonymous +app_update 232330 validate +quit

# Create SDK symlink for 64-bit compatibility
RUN mkdir -p ~/.steam/sdk32 && `
    ln -s /home/steam/linux32/steamclient.so ~/.steam/sdk32/

# Copy configurations and plugins
COPY --chown=steam:steam dist/cstrike /home/steam/css/cstrike
COPY --chown=steam:steam scripts/entrypoint.sh /home/steam/

# Environment variables
ENV CSS_HOSTNAME="Counter-Strike Source Server"
ENV CSS_PASSWORD=""
ENV RCON_PASSWORD=""
ENV CSS_MAP="de_dust2"
ENV CSS_MAXPLAYERS="24"
ENV CSS_TICKRATE="66"

# Expose ports
EXPOSE 27015/tcp 27015/udp 27020/udp 27005/udp 26901/udp

ENTRYPOINT ["/home/steam/entrypoint.sh"]
```

### 1.2 Entrypoint Script

```bash
#!/bin/bash
set -e

# Handle update request
if [ "$1" == "update" ]; then
    echo "Updating Counter-Strike: Source..."
    ./steamcmd.sh +force_install_dir ./css +login anonymous +app_update 232330 validate +quit
    exit 0
fi

# Start the server
cd css
exec ./srcds_run -game cstrike `
    +map "$CSS_MAP" `
    +maxplayers "$CSS_MAXPLAYERS" `
    -tickrate "$CSS_TICKRATE" `
    +hostname "$CSS_HOSTNAME" `
    +sv_password "$CSS_PASSWORD" `
    +rcon_password "$RCON_PASSWORD" `
    +exec server.cfg `
    -norestart `
    "$@"
```

---

## Phase 2: MetaMod & SourceMod Installation

This is a critical phase - MetaMod and SourceMod are the foundation for all server plugins.

### 2.1 Understanding the Stack

```
┌─────────────────────────────────────┐
│         SourceMod Plugins           │  ← .smx files (Quake Sounds, MapChooser, etc.)
│         (scripting layer)           │
├─────────────────────────────────────┤
│           SourceMod                 │  ← Plugin framework, admin system
│      (sourcemod.net)                │
├─────────────────────────────────────┤
│         MetaMod:Source              │  ← Plugin loader, hooks into engine
│      (metamodsource.net)            │
├─────────────────────────────────────┤
│     Counter-Strike: Source          │  ← Game server (srcds)
│        (Source Engine)              │
└─────────────────────────────────────┘
```

### 2.2 Version Information

Check for latest stable versions before building:

| Component | Download URL | Notes |
|-----------|--------------|-------|
| MetaMod:Source | https://www.metamodsource.net/downloads.php?branch=stable | Get Linux build |
| SourceMod | https://www.sourcemod.net/downloads.php?branch=stable | Get Linux build |

**Current Stable Versions (verify before build):**
- MetaMod:Source: 1.12.x (mmsource-1.12.0-gitXXXX-linux.tar.gz)
- SourceMod: 1.12.x (sourcemod-1.12.0-gitXXXX-linux.tar.gz)

### 2.3 Dockerfile Installation

```dockerfile
# === METAMOD & SOURCEMOD INSTALLATION ===

# Set versions as build args for easy updates
ARG METAMOD_VERSION=1.12
ARG SOURCEMOD_VERSION=1.12

# Download and install MetaMod:Source
RUN echo "Installing MetaMod:Source..." && \
    METAMOD_URL=$(curl -s "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/mmsource-latest-linux" | head -1) && \
    wget -q "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/${METAMOD_URL}" -O /tmp/metamod.tar.gz && \
    tar -xzf /tmp/metamod.tar.gz -C /home/steam/css/cstrike && \
    rm /tmp/metamod.tar.gz

# Download and install SourceMod
RUN echo "Installing SourceMod..." && \
    SM_URL=$(curl -s "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/sourcemod-latest-linux" | head -1) && \
    wget -q "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/${SM_URL}" -O /tmp/sourcemod.tar.gz && \
    tar -xzf /tmp/sourcemod.tar.gz -C /home/steam/css/cstrike && \
    rm /tmp/sourcemod.tar.gz

# Create MetaMod VDF loader file
RUN echo '"Plugin"' > /home/steam/css/cstrike/addons/metamod.vdf && \
    echo '{' >> /home/steam/css/cstrike/addons/metamod.vdf && \
    echo '    "file" "../cstrike/addons/metamod/bin/server"' >> /home/steam/css/cstrike/addons/metamod.vdf && \
    echo '}' >> /home/steam/css/cstrike/addons/metamod.vdf
```

**Alternative: Pre-downloaded Archives**

If you prefer to bundle specific versions in your repo:

```dockerfile
# Copy pre-downloaded MetaMod and SourceMod
COPY --chown=steam:steam mods/mmsource-1.12.0-git1200-linux.tar.gz /tmp/
COPY --chown=steam:steam mods/sourcemod-1.12.0-git7000-linux.tar.gz /tmp/

RUN tar -xzf /tmp/mmsource-*.tar.gz -C /home/steam/css/cstrike && \
    tar -xzf /tmp/sourcemod-*.tar.gz -C /home/steam/css/cstrike && \
    rm /tmp/*.tar.gz
```

### 2.4 MetaMod Configuration

#### metamod.vdf (Required)
Location: `/home/steam/css/cstrike/addons/metamod.vdf`

```
"Plugin"
{
    "file" "../cstrike/addons/metamod/bin/server"
}
```

This file tells the Source engine to load MetaMod. Without it, nothing works.

#### metaplugins.ini (Optional)
Location: `/home/steam/css/cstrike/addons/metamod/metaplugins.ini`

Lists additional MetaMod plugins (SourceMod registers itself automatically).

### 2.5 SourceMod Directory Structure

After installation, SourceMod creates this structure:

```
cstrike/addons/sourcemod/
├── bin/                      # SourceMod binaries (DO NOT MODIFY)
│   ├── sourcemod_mm.so       # MetaMod plugin
│   └── ...
├── configs/                  # ⭐ CONFIGURATION FILES
│   ├── admin_groups.cfg      # Admin permission groups
│   ├── admin_levels.cfg      # Admin flag definitions
│   ├── admin_overrides.cfg   # Command permission overrides
│   ├── admins.cfg            # Admin definitions (advanced)
│   ├── admins_simple.ini     # ⭐ Simple admin list (recommended)
│   ├── core.cfg              # SourceMod core settings
│   ├── databases.cfg         # Database connections (MySQL/SQLite)
│   └── languages.cfg         # Language settings
├── data/                     # Plugin persistent data storage
│   └── sqlite/               # SQLite databases
├── extensions/               # Binary extensions (.so files)
│   ├── bintools.ext.so
│   ├── clientprefs.ext.so
│   ├── dbi.mysql.ext.so
│   ├── dbi.sqlite.ext.so
│   ├── sdkhooks.ext.so
│   ├── sdktools.ext.so
│   └── topmenus.ext.so
├── gamedata/                 # Game memory signatures (DO NOT MODIFY)
├── logs/                     # SourceMod logs
├── plugins/                  # ⭐ ACTIVE PLUGINS (.smx files)
│   ├── admin-flatfile.smx    # Loads admins from files
│   ├── adminhelp.smx         # Admin help commands
│   ├── adminmenu.smx         # Admin menu system
│   ├── antiflood.smx         # Chat flood protection
│   ├── basebans.smx          # Ban system
│   ├── basechat.smx          # Chat commands
│   ├── basecomm.smx          # Communication controls
│   ├── basecommands.smx      # Basic admin commands
│   ├── basetriggers.smx      # Trigger phrases
│   ├── basevotes.smx         # Voting system
│   ├── clientprefs.smx       # Client preferences/cookies
│   ├── funcommands.smx       # Fun admin commands
│   ├── funvotes.smx          # Fun vote options
│   ├── playercommands.smx    # Player targeting commands
│   └── disabled/             # ⭐ DISABLED PLUGINS (move here to disable)
├── scripting/                # Plugin source code (.sp files)
│   └── include/              # SourceMod include files
└── translations/             # Language files for plugins
```

### 2.6 Admin Configuration

#### admins_simple.ini (Recommended Method)
Location: `/home/steam/css/cstrike/addons/sourcemod/configs/admins_simple.ini`

```ini
; SourceMod Admin File (Simple Format)
;
; Format: "identity" "flags" ["password"]
;
; Identity types:
;   STEAM_X:X:XXXXXXXX  - Steam2 ID
;   [U:1:XXXXXXXX]      - Steam3 ID
;
; Common flag combinations:
;   "99:z"  - Full root admin (all permissions)
;   "99:b"  - Ban admin (can ban players)
;   "99:c"  - Kick admin (can kick players)
;   "99:d"  - Slay admin (can slay/slap)
;   "99:f"  - Map admin (can change maps)
;
; The "99" is immunity level (higher = more immune to admin commands)

; === SERVER ADMINS ===
"STEAM_0:1:12345678"    "99:z"      ; YourName - Root Admin
"STEAM_0:0:87654321"    "50:bcdf"   ; ModeratorName - Basic Mod

; === VIP/RESERVED SLOTS ===
; "STEAM_0:1:11111111"  "10:a"      ; VIP Player - Reserved slot only
```

#### Admin Flags Reference

| Flag | Permission | Description |
|------|------------|-------------|
| `a` | reservation | Reserved slot access |
| `b` | generic | Generic admin (required for admin menu) |
| `c` | kick | Kick players |
| `d` | ban | Ban players |
| `e` | unban | Unban players |
| `f` | slay | Slay/slap/harm players |
| `g` | changemap | Change maps |
| `h` | cvar | Change server cvars |
| `i` | config | Execute configs |
| `j` | chat | Special chat privileges |
| `k` | vote | Start votes |
| `l` | password | Change server password |
| `m` | rcon | RCON access |
| `n` | cheats | sv_cheats commands |
| `o` | root | Magically enables all flags |
| `z` | root | All permissions (same as o) |

### 2.7 Essential Plugins Installation

#### Built-in Plugins (Included with SourceMod)
These come pre-installed - just ensure they're not in the `disabled/` folder:

| Plugin | File | Purpose |
|--------|------|---------|
| Admin Menu | `adminmenu.smx` | Admin command menu |
| Base Bans | `basebans.smx` | Ban management |
| Base Commands | `basecommands.smx` | kick, map, rcon, etc. |
| Base Votes | `basevotes.smx` | Vote kick/ban/map |
| Anti-Flood | `antiflood.smx` | Prevent chat spam |
| Fun Commands | `funcommands.smx` | slap, slay, beacon, etc. |

#### Additional Plugins (Download & Install)

| Plugin | Source | Purpose |
|--------|--------|---------|
| MapChooser Extended | [AlliedModders](https://forums.alliedmods.net/showthread.php?t=156974) | Advanced map voting |
| Rock The Vote | Built-in or MCE | Player-initiated map votes |
| Nominations | Built-in or MCE | Map nomination system |
| Quake Sounds | [AlliedModders](https://forums.alliedmods.net/showthread.php?t=224316) | Kill streak sounds |
| GunGame | [AlliedModders](https://forums.alliedmods.net/showthread.php?t=93977) | GunGame mode |
| Warmod | [AlliedModders](https://forums.alliedmods.net/showthread.php?t=225474) | Competitive match mode |

#### Installing Additional Plugins

**Method 1: During Docker Build**
```dockerfile
# Copy custom plugins
COPY --chown=steam:steam plugins/*.smx /home/steam/css/cstrike/addons/sourcemod/plugins/
COPY --chown=steam:steam plugins/configs/ /home/steam/css/cstrike/addons/sourcemod/configs/
```

**Method 2: Via Volume Mount (Recommended for Flexibility)**
```yaml
volumes:
  - ./custom-plugins:/home/steam/css/cstrike/addons/sourcemod/plugins/custom:ro
```

**Method 3: Runtime Installation**
```bash
# Copy plugin into running container
docker cp quake_sounds.smx css-server:/home/steam/css/cstrike/addons/sourcemod/plugins/

# Reload plugins via RCON
# In server console or via RCON:
sm plugins refresh
```

### 2.8 Plugin Configuration Files

Many plugins require configuration files in `configs/`:

#### MapChooser Extended Config
Location: `configs/mapchooser_extended.cfg`
```
// MapChooser Extended Configuration
"mapchooser_extended"
{
    "exclude"           "5"         // Maps to exclude from vote
    "include"           "5"         // Maps to include in vote
    "novote"            "1"         // Allow "No Vote" option
    "extend_timestep"   "15"        // Minutes to extend
    "extend_roundstep"  "5"         // Rounds to extend
    "extend_fragstep"   "10"        // Frags to extend
    "vote_duration"     "20"        // Vote time in seconds
}
```

#### Quake Sounds Config
Location: `configs/quake_sounds.cfg` (varies by plugin version)
```
"QuakeSounds"
{
    "FirstBlood"        "sound/quake/firstblood.mp3"
    "HeadShot"          "sound/quake/headshot.mp3"
    "Humiliation"       "sound/quake/humiliation.mp3"
    "DoubleKill"        "sound/quake/doublekill.mp3"
    "MultiKill"         "sound/quake/multikill.mp3"
    "MegaKill"          "sound/quake/megakill.mp3"
    "UltraKill"         "sound/quake/ultrakill.mp3"
    "KillingSpree"      "sound/quake/killingspree.mp3"
    "Rampage"           "sound/quake/rampage.mp3"
    "Dominating"        "sound/quake/dominating.mp3"
    "Unstoppable"       "sound/quake/unstoppable.mp3"
    "GodLike"           "sound/quake/godlike.mp3"
}
```

### 2.9 SourceMod Core Configuration

Location: `configs/core.cfg`

```cfg
"Core"
{
    "FollowCSGOServerGuidelines"    "no"    // Not CSGO, so no
    "ServerLang"                    "en"    // Default language

    // Logging
    "LogMode"                       "daily" // daily, map, or game
    "EnableLogging"                 "yes"
    "DebugLogs"                     "no"

    // Anti-cheat / pure
    "FilterExtensions"              "yes"
    "FilterBinaries"                "yes"

    // Display
    "ShowBanReason"                 "yes"
    "ShowVotingPercentages"         "yes"
}
```

### 2.10 Database Configuration (Optional)

For plugins that support MySQL (stats, bans, etc.):

Location: `configs/databases.cfg`

```cfg
"Databases"
{
    "driver_default"    "sqlite"    // Default to SQLite (no setup needed)

    // SQLite is built-in and requires no configuration
    "storage-local"
    {
        "driver"    "sqlite"
        "database"  "sourcemod-local"
    }

    // MySQL example (uncomment and configure if needed)
    // "default"
    // {
    //     "driver"    "mysql"
    //     "host"      "localhost"
    //     "database"  "sourcemod"
    //     "user"      "sourcemod"
    //     "pass"      "password"
    //     "port"      "3306"
    // }
}
```

### 2.11 Volume Mounts for SourceMod/MetaMod

For maximum flexibility, mount these directories:

```yaml
volumes:
  # === SOURCEMOD MOUNTS ===

  # Plugins - Add/remove plugins without rebuilding
  - ./data/sourcemod/plugins:/home/steam/css/cstrike/addons/sourcemod/plugins

  # Configs - Admin lists, plugin settings
  - ./data/sourcemod/configs:/home/steam/css/cstrike/addons/sourcemod/configs

  # Data - Plugin databases, persistent storage
  - ./data/sourcemod/data:/home/steam/css/cstrike/addons/sourcemod/data

  # Logs - SourceMod logs
  - ./data/sourcemod/logs:/home/steam/css/cstrike/addons/sourcemod/logs

  # Translations - Language files (optional)
  - ./data/sourcemod/translations:/home/steam/css/cstrike/addons/sourcemod/translations

  # === METAMOD MOUNTS (rarely needed) ===
  # - ./data/metamod:/home/steam/css/cstrike/addons/metamod

  # === CUSTOM SOUNDS (for Quake Sounds, etc.) ===
  - ./data/sound:/home/steam/css/cstrike/sound
```

### 2.12 Verification Commands

After server starts, verify installation via RCON or server console:

```
// Check MetaMod is loaded
meta list
// Should show: SourceMod (X plugins)

// Check SourceMod version
sm version
// Should show: SourceMod Version Information

// List loaded plugins
sm plugins list
// Shows all active plugins with status

// Refresh plugins after adding new ones
sm plugins refresh

// Check for plugin errors
sm plugins info <plugin_name>
```

### 2.13 Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Unknown command: sm" | SourceMod not loaded | Check metamod.vdf exists and is correct |
| "meta list" shows nothing | MetaMod not loaded | Verify addons/metamod.vdf path |
| Plugin not loading | Missing dependency | Check sm logs for errors |
| Admin commands don't work | Not in admins_simple.ini | Add Steam ID with proper flags |
| "Plugin failed to load" | Wrong SM version | Download plugin for your SM version |

### 2.14 Plugin Download Script

```bash
#!/bin/bash
# scripts/download-plugins.sh
# Run this to download MetaMod, SourceMod, and common plugins

set -e

MODS_DIR="./mods"
PLUGINS_DIR="./mods/plugins"
mkdir -p "$MODS_DIR" "$PLUGINS_DIR"

echo "=== Downloading MetaMod:Source ==="
METAMOD_VERSION="1.12"
METAMOD_FILE=$(curl -s "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/mmsource-latest-linux")
wget -O "$MODS_DIR/metamod.tar.gz" "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/${METAMOD_FILE}"
echo "Downloaded: $METAMOD_FILE"

echo "=== Downloading SourceMod ==="
SM_VERSION="1.12"
SM_FILE=$(curl -s "https://sm.alliedmods.net/smdrop/${SM_VERSION}/sourcemod-latest-linux")
wget -O "$MODS_DIR/sourcemod.tar.gz" "https://sm.alliedmods.net/smdrop/${SM_VERSION}/${SM_FILE}"
echo "Downloaded: $SM_FILE"

echo "=== Plugin Downloads ==="
echo "The following plugins must be downloaded manually from AlliedModders:"
echo ""
echo "1. MapChooser Extended:"
echo "   https://forums.alliedmods.net/showthread.php?t=156974"
echo ""
echo "2. Quake Sounds:"
echo "   https://forums.alliedmods.net/showthread.php?t=224316"
echo ""
echo "3. Rock The Vote Extended:"
echo "   (Usually included with MapChooser Extended)"
echo ""
echo "Place downloaded .smx files in: $PLUGINS_DIR/"
echo ""
echo "=== Download Complete ==="
echo "MetaMod: $MODS_DIR/metamod.tar.gz"
echo "SourceMod: $MODS_DIR/sourcemod.tar.gz"
```

---

## Phase 3: Server Configuration

### 3.1 server.cfg (Comprehensive)

Based on foxyserver's detailed configuration with modern updates:

```cfg
// ===========================================
// Counter-Strike: Source Server Configuration
// ===========================================

// --- Server Identity ---
hostname "Counter-Strike Source Server"
sv_contact "admin@example.com"
sv_region 255

// --- Network Settings ---
sv_maxrate 0
sv_minrate 20000
sv_maxupdaterate 100
sv_minupdaterate 30
sv_maxcmdrate 100
sv_mincmdrate 30

// --- Security ---
sv_pure 2
sv_consistency 1
sv_cheats 0
sv_allowupload 0
sv_allowdownload 1

// --- RCON Security ---
sv_rcon_banpenalty 30
sv_rcon_minfailures 5
sv_rcon_maxfailures 10

// --- Gameplay ---
mp_autoteambalance 1
mp_limitteams 2
mp_friendlyfire 0
mp_flashlight 1
mp_footsteps 1
mp_falldamage 1
mp_tkpunish 0
mp_autokick 0

// --- Round Settings ---
mp_timelimit 30
mp_roundtime 2.5
mp_freezetime 6
mp_buytime 90
mp_startmoney 800
mp_c4timer 45
mp_maxrounds 0
mp_winlimit 0

// --- Spectator ---
mp_allowspectators 1
mp_forcecamera 1
mp_fadetoblack 0

// --- Communication ---
sv_voiceenable 1
sv_alltalk 0
mp_chattime 10

// --- Physics ---
sv_gravity 800
sv_accelerate 5
sv_airaccelerate 10
sv_friction 4
sv_stopspeed 75

// --- Bot Configuration ---
bot_quota 10
bot_quota_mode fill
bot_join_after_player 1
bot_difficulty 2
bot_chatter minimal
bot_auto_vacate 1

// --- Logging ---
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
mp_logdetail 3

// --- Execute Additional Configs ---
exec banned_user.cfg
exec banned_ip.cfg
exec my-server.cfg
```

### 3.2 mapcycle.txt

```
de_dust2
de_inferno
de_nuke
cs_office
cs_italy
de_aztec
de_cbble
de_train
cs_assault
de_dust
de_piranesi
de_prodigy
cs_havana
cs_militia
de_chateau
de_port
de_tides
```

---

## Phase 4: Volumes & Environment Variables (Complete Reference)

This section documents ALL customizable aspects of the server. The design philosophy is:
- **Volumes** = Files/folders you want to persist or customize
- **Environment Variables** = Runtime settings that don't require file changes

### 4.1 Volume Mounts (Complete List)

#### Directory Structure Inside Container
```
/home/steam/css/cstrike/
├── addons/
│   ├── metamod/              # MetaMod binaries
│   └── sourcemod/
│       ├── bin/              # SourceMod binaries
│       ├── configs/          # Admin configs, plugin settings
│       ├── data/             # Plugin persistent data
│       ├── extensions/       # SM extensions (.so files)
│       ├── gamedata/         # Game memory signatures
│       ├── logs/             # SourceMod logs
│       ├── plugins/          # Active plugins (.smx)
│       │   └── disabled/     # Disabled plugins
│       ├── scripting/        # Plugin source code (.sp)
│       └── translations/     # Language files
├── cfg/                      # Server configurations
├── maps/                     # Map files (.bsp)
├── materials/                # Textures, sprays
├── models/                   # Player/weapon models
├── sound/                    # Custom sounds
├── download/                 # Client downloadable content
└── logs/                     # Server logs
```

#### Volume Mount Reference Table

| Volume Purpose | Container Path | Mount Type | When to Use |
|----------------|----------------|------------|-------------|
| **CONFIGURATIONS** ||||
| Main server config | `/home/steam/css/cstrike/cfg/server.cfg` | File (ro) | Override default server settings |
| Custom overrides | `/home/steam/css/cstrike/cfg/my-server.cfg` | File (rw) | Your personal tweaks |
| Map rotation | `/home/steam/css/cstrike/cfg/mapcycle.txt` | File (rw) | Custom map cycle |
| MOTD | `/home/steam/css/cstrike/cfg/motd.txt` | File (ro) | Welcome message |
| Banned users | `/home/steam/css/cstrike/cfg/banned_user.cfg` | File (rw) | Persistent bans |
| Banned IPs | `/home/steam/css/cstrike/cfg/banned_ip.cfg` | File (rw) | Persistent IP bans |
| All configs | `/home/steam/css/cstrike/cfg` | Directory | Full config control |
| **MAPS** ||||
| Custom maps | `/home/steam/css/cstrike/maps` | Directory | Add workshop/custom maps |
| **SOURCEMOD** ||||
| SM Plugins | `/home/steam/css/cstrike/addons/sourcemod/plugins` | Directory | Add/remove plugins |
| SM Configs | `/home/steam/css/cstrike/addons/sourcemod/configs` | Directory | Plugin configurations |
| Admin list | `/home/steam/css/cstrike/addons/sourcemod/configs/admins_simple.ini` | File (rw) | Server admins |
| Admin groups | `/home/steam/css/cstrike/addons/sourcemod/configs/admin_groups.cfg` | File (rw) | Admin permission groups |
| Admin overrides | `/home/steam/css/cstrike/addons/sourcemod/configs/admin_overrides.cfg` | File (rw) | Command overrides |
| Database config | `/home/steam/css/cstrike/addons/sourcemod/configs/databases.cfg` | File (rw) | MySQL/SQLite settings |
| Core config | `/home/steam/css/cstrike/addons/sourcemod/configs/core.cfg` | File (ro) | SourceMod core settings |
| SM Data | `/home/steam/css/cstrike/addons/sourcemod/data` | Directory | Plugin persistent data |
| SM Logs | `/home/steam/css/cstrike/addons/sourcemod/logs` | Directory | SourceMod logs |
| SM Translations | `/home/steam/css/cstrike/addons/sourcemod/translations` | Directory | Language files |
| **CUSTOM CONTENT** ||||
| Sounds | `/home/steam/css/cstrike/sound` | Directory | Custom sounds (Quake, etc.) |
| Materials | `/home/steam/css/cstrike/materials` | Directory | Textures, sprays |
| Models | `/home/steam/css/cstrike/models` | Directory | Custom models |
| Downloads | `/home/steam/css/cstrike/download` | Directory | Fast download content |
| **LOGS** ||||
| Server logs | `/home/steam/css/cstrike/logs` | Directory | Game server logs |
| **FULL PERSISTENCE** ||||
| Entire game folder | `/home/steam/css` | Directory | Full server persistence |

#### Recommended Volume Strategy

**Option A: Minimal (Config Only)**
Mount only what you need to customize:
```yaml
volumes:
  - ./data/cfg:/home/steam/css/cstrike/cfg
  - ./data/maps:/home/steam/css/cstrike/maps
  - ./data/sourcemod/plugins:/home/steam/css/cstrike/addons/sourcemod/plugins
  - ./data/sourcemod/configs:/home/steam/css/cstrike/addons/sourcemod/configs
```

**Option B: Full Persistence**
Mount the entire cstrike folder for complete control:
```yaml
volumes:
  - ./data/cstrike:/home/steam/css/cstrike
```

**Option C: Named Volumes + Selective Overrides**
Use Docker volumes for persistence, bind mounts for customization:
```yaml
volumes:
  - css-server-data:/home/steam/css
  - ./custom/cfg:/home/steam/css/cstrike/cfg:ro
  - ./custom/maps:/home/steam/css/cstrike/maps:ro
```

---

### 4.2 Environment Variables (Complete List)

#### Server Identity & Access

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_HOSTNAME` | `Counter-Strike Source Server` | Server name shown in browser |
| `CSS_PASSWORD` | `` (empty) | Password to join server |
| `RCON_PASSWORD` | `` (empty) | Remote console password |
| `CSS_CONTACT` | `` | Admin contact email |
| `CSS_REGION` | `255` | Server region (255=worldwide) |

#### Network & Performance

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_PORT` | `27015` | Main server port |
| `CSS_MAXPLAYERS` | `24` | Maximum player slots |
| `CSS_TICKRATE` | `66` | Server tickrate (66 or 100) |
| `CSS_MAXRATE` | `0` | Max bandwidth per client (0=unlimited) |
| `CSS_MINRATE` | `20000` | Min bandwidth per client |
| `CSS_MAXUPDATERATE` | `100` | Max updates per second to clients |
| `CSS_MINUPDATERATE` | `30` | Min updates per second to clients |

#### Gameplay Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_MAP` | `de_dust2` | Starting map |
| `CSS_FRIENDLYFIRE` | `0` | Friendly fire (0=off, 1=on) |
| `CSS_ALLTALK` | `0` | All talk voice (0=team only, 1=all) |
| `CSS_TIMELIMIT` | `30` | Map time limit in minutes |
| `CSS_ROUNDTIME` | `2.5` | Round time in minutes |
| `CSS_FREEZETIME` | `6` | Freeze time before round |
| `CSS_BUYTIME` | `90` | Buy time in seconds |
| `CSS_STARTMONEY` | `800` | Starting money |
| `CSS_C4TIMER` | `45` | Bomb timer in seconds |
| `CSS_MAXROUNDS` | `0` | Max rounds (0=unlimited) |
| `CSS_WINLIMIT` | `0` | Win limit (0=unlimited) |
| `CSS_GRAVITY` | `800` | Gravity (800=normal) |
| `CSS_FALLDAMAGE` | `1` | Fall damage (0=off, 1=on) |

#### Bot Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_BOT_QUOTA` | `0` | Number of bots (0=none) |
| `CSS_BOT_QUOTA_MODE` | `fill` | Bot mode: `fill`, `match`, `normal` |
| `CSS_BOT_DIFFICULTY` | `2` | Bot skill (0=easy, 3=expert) |
| `CSS_BOT_CHATTER` | `minimal` | Bot voice: `off`, `minimal`, `normal`, `radio` |
| `CSS_BOT_JOIN_AFTER_PLAYER` | `1` | Bots wait for humans (0=no, 1=yes) |
| `CSS_BOT_AUTO_VACATE` | `1` | Bots leave for humans (0=no, 1=yes) |
| `CSS_BOT_PREFIX` | `[BOT]` | Bot name prefix |

#### Security

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_PURE` | `2` | sv_pure level (0=off, 1=loose, 2=strict) |
| `CSS_CHEATS` | `0` | Allow cheats (0=no, 1=yes) |
| `CSS_ALLOWUPLOAD` | `0` | Allow client uploads (0=no, 1=yes) |
| `CSS_ALLOWDOWNLOAD` | `1` | Allow client downloads (0=no, 1=yes) |
| `CSS_RCON_BANPENALTY` | `30` | RCON fail ban time (seconds) |
| `CSS_RCON_MAXFAILURES` | `10` | RCON failures before ban |

#### Fast Download / Content Delivery

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_DOWNLOADURL` | `` (empty) | Fast download URL (sv_downloadurl) |
| `CSS_ALLOWDOWNLOAD` | `1` | Enable downloads |
| `CSS_MAXFILESIZE` | `64` | Max download file size (MB) |

#### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_LOG` | `on` | Enable logging |
| `CSS_LOGBANS` | `1` | Log bans |
| `CSS_LOGDETAIL` | `3` | Log detail level (0-3) |

#### SourceMod Specific

| Variable | Default | Description |
|----------|---------|-------------|
| `SM_DEBUG` | `0` | SourceMod debug mode |
| `SM_BASEPATH` | `sourcemod` | SourceMod base path |
| `SM_SHOW_ACTIVITY` | `13` | Admin activity visibility |

#### Steam Integration

| Variable | Default | Description |
|----------|---------|-------------|
| `STEAM_GSLT` | `` | Game Server Login Token (required for public) |
| `STEAM_WEBAPI_KEY` | `` | Steam Web API key (for some plugins) |

---

### 4.3 Docker Compose (Full Featured)

```yaml
version: '3.8'

services:
  css-server:
    build:
      context: .
      dockerfile: Dockerfile
    image: css-server:latest
    container_name: css-server
    restart: unless-stopped

    # Network - use host for best performance, or bridge with ports
    network_mode: host
    # OR use port mapping:
    # ports:
    #   - "27015:27015/tcp"    # RCON
    #   - "27015:27015/udp"    # Game traffic
    #   - "27020:27020/udp"    # Client port
    #   - "27005:27005/udp"    # HLTV
    #   - "26901:26901/udp"    # NAT traversal

    environment:
      # Server Identity
      - CSS_HOSTNAME=${CSS_HOSTNAME:-My CSS Server}
      - CSS_PASSWORD=${CSS_PASSWORD:-}
      - RCON_PASSWORD=${RCON_PASSWORD:-changethis}
      - CSS_CONTACT=${CSS_CONTACT:-admin@example.com}
      - CSS_REGION=${CSS_REGION:-255}

      # Network
      - CSS_PORT=${CSS_PORT:-27015}
      - CSS_MAXPLAYERS=${CSS_MAXPLAYERS:-24}
      - CSS_TICKRATE=${CSS_TICKRATE:-66}

      # Gameplay
      - CSS_MAP=${CSS_MAP:-de_dust2}
      - CSS_FRIENDLYFIRE=${CSS_FRIENDLYFIRE:-0}
      - CSS_ALLTALK=${CSS_ALLTALK:-0}
      - CSS_TIMELIMIT=${CSS_TIMELIMIT:-30}
      - CSS_ROUNDTIME=${CSS_ROUNDTIME:-2.5}
      - CSS_FREEZETIME=${CSS_FREEZETIME:-6}
      - CSS_STARTMONEY=${CSS_STARTMONEY:-800}
      - CSS_GRAVITY=${CSS_GRAVITY:-800}

      # Bots
      - CSS_BOT_QUOTA=${CSS_BOT_QUOTA:-0}
      - CSS_BOT_QUOTA_MODE=${CSS_BOT_QUOTA_MODE:-fill}
      - CSS_BOT_DIFFICULTY=${CSS_BOT_DIFFICULTY:-2}

      # Security
      - CSS_PURE=${CSS_PURE:-2}
      - STEAM_GSLT=${STEAM_GSLT:-}

      # Fast Download
      - CSS_DOWNLOADURL=${CSS_DOWNLOADURL:-}

    volumes:
      # Option A: Full game persistence (recommended for production)
      - css-gamedata:/home/steam/css

      # Option B: Granular control (uncomment what you need)
      # Configs
      # - ./data/cfg:/home/steam/css/cstrike/cfg
      # - ./data/mapcycle.txt:/home/steam/css/cstrike/cfg/mapcycle.txt:ro

      # Maps
      # - ./data/maps:/home/steam/css/cstrike/maps

      # SourceMod
      # - ./data/sourcemod/plugins:/home/steam/css/cstrike/addons/sourcemod/plugins
      # - ./data/sourcemod/configs:/home/steam/css/cstrike/addons/sourcemod/configs
      # - ./data/sourcemod/data:/home/steam/css/cstrike/addons/sourcemod/data
      # - ./data/sourcemod/logs:/home/steam/css/cstrike/addons/sourcemod/logs

      # Custom Content
      # - ./data/sound:/home/steam/css/cstrike/sound
      # - ./data/materials:/home/steam/css/cstrike/materials
      # - ./data/models:/home/steam/css/cstrike/models

      # Logs
      # - ./data/logs:/home/steam/css/cstrike/logs

      # Bans (persistent across rebuilds)
      # - ./data/banned_user.cfg:/home/steam/css/cstrike/cfg/banned_user.cfg
      # - ./data/banned_ip.cfg:/home/steam/css/cstrike/cfg/banned_ip.cfg

    # Resource limits (optional)
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

volumes:
  css-gamedata:
    name: css-server-data
```

### 4.4 .env.example (Complete)

```bash
# ===========================================
# Counter-Strike: Source Server Configuration
# ===========================================
# Copy this to .env and customize

# --- Server Identity ---
CSS_HOSTNAME=My Awesome CSS Server
CSS_PASSWORD=
RCON_PASSWORD=changethis_immediately
CSS_CONTACT=admin@example.com
CSS_REGION=255

# --- Network ---
CSS_PORT=27015
CSS_MAXPLAYERS=24
CSS_TICKRATE=66

# --- Gameplay ---
CSS_MAP=de_dust2
CSS_FRIENDLYFIRE=0
CSS_ALLTALK=0
CSS_TIMELIMIT=30
CSS_ROUNDTIME=2.5
CSS_FREEZETIME=6
CSS_BUYTIME=90
CSS_STARTMONEY=800
CSS_C4TIMER=45
CSS_MAXROUNDS=0
CSS_WINLIMIT=0
CSS_GRAVITY=800
CSS_FALLDAMAGE=1

# --- Bots ---
CSS_BOT_QUOTA=10
CSS_BOT_QUOTA_MODE=fill
CSS_BOT_DIFFICULTY=2
CSS_BOT_CHATTER=minimal
CSS_BOT_JOIN_AFTER_PLAYER=1
CSS_BOT_AUTO_VACATE=1
CSS_BOT_PREFIX=[BOT]

# --- Security ---
CSS_PURE=2
CSS_CHEATS=0
CSS_ALLOWUPLOAD=0
CSS_ALLOWDOWNLOAD=1
CSS_RCON_BANPENALTY=30
CSS_RCON_MAXFAILURES=10

# --- Fast Download ---
# Set this if you have a web server hosting maps/sounds
CSS_DOWNLOADURL=
CSS_MAXFILESIZE=64

# --- Logging ---
CSS_LOG=on
CSS_LOGBANS=1
CSS_LOGDETAIL=3

# --- Steam (Required for public servers) ---
# Get a token at: https://steamcommunity.com/dev/managegameservers
STEAM_GSLT=
STEAM_WEBAPI_KEY=
```

---

### 4.5 Updated Entrypoint Script (Environment Variable Aware)

```bash
#!/bin/bash
set -e

# Handle update request
if [ "$1" == "update" ]; then
    echo "Updating Counter-Strike: Source..."
    ./steamcmd.sh +force_install_dir ./css +login anonymous +app_update 232330 validate +quit
    exit 0
fi

# Generate dynamic server.cfg from environment variables
generate_env_config() {
    cat > /home/steam/css/cstrike/cfg/env_settings.cfg << EOF
// Auto-generated from environment variables - DO NOT EDIT
// These settings override server.cfg

// Server Identity
hostname "${CSS_HOSTNAME:-Counter-Strike Source Server}"
sv_contact "${CSS_CONTACT:-}"
sv_region ${CSS_REGION:-255}

// Network
sv_maxrate ${CSS_MAXRATE:-0}
sv_minrate ${CSS_MINRATE:-20000}
sv_maxupdaterate ${CSS_MAXUPDATERATE:-100}
sv_minupdaterate ${CSS_MINUPDATERATE:-30}

// Gameplay
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

// Bots
bot_quota ${CSS_BOT_QUOTA:-0}
bot_quota_mode ${CSS_BOT_QUOTA_MODE:-fill}
bot_difficulty ${CSS_BOT_DIFFICULTY:-2}
bot_chatter ${CSS_BOT_CHATTER:-minimal}
bot_join_after_player ${CSS_BOT_JOIN_AFTER_PLAYER:-1}
bot_auto_vacate ${CSS_BOT_AUTO_VACATE:-1}
bot_prefix "${CSS_BOT_PREFIX:-[BOT]}"

// Security
sv_pure ${CSS_PURE:-2}
sv_cheats ${CSS_CHEATS:-0}
sv_allowupload ${CSS_ALLOWUPLOAD:-0}
sv_allowdownload ${CSS_ALLOWDOWNLOAD:-1}
sv_rcon_banpenalty ${CSS_RCON_BANPENALTY:-30}
sv_rcon_maxfailures ${CSS_RCON_MAXFAILURES:-10}

// Fast Download
sv_downloadurl "${CSS_DOWNLOADURL:-}"
net_maxfilesize ${CSS_MAXFILESIZE:-64}

// Logging
log ${CSS_LOG:-on}
sv_logbans ${CSS_LOGBANS:-1}
mp_logdetail ${CSS_LOGDETAIL:-3}
EOF
}

echo "Generating configuration from environment variables..."
generate_env_config

# Build server arguments
SERVER_ARGS=""

# Add GSLT if provided (required for public servers)
if [ -n "$STEAM_GSLT" ]; then
    SERVER_ARGS="$SERVER_ARGS +sv_setsteamaccount $STEAM_GSLT"
fi

# Start the server
cd css
exec ./srcds_run -game cstrike \
    -port "${CSS_PORT:-27015}" \
    +map "${CSS_MAP:-de_dust2}" \
    +maxplayers "${CSS_MAXPLAYERS:-24}" \
    -tickrate "${CSS_TICKRATE:-66}" \
    +sv_password "${CSS_PASSWORD:-}" \
    +rcon_password "${RCON_PASSWORD:-}" \
    +exec server.cfg \
    +exec env_settings.cfg \
    -norestart \
    $SERVER_ARGS \
    "$@"
```

---

### 4.6 Quick Start Examples

#### Minimal (Just Works)
```bash
docker run -d --net=host \
  -e RCON_PASSWORD=secret123 \
  css-server
```

#### With Custom Maps
```bash
docker run -d --net=host \
  -e CSS_HOSTNAME="Custom Maps Server" \
  -e RCON_PASSWORD=secret123 \
  -v ./my-maps:/home/steam/css/cstrike/maps \
  -v ./my-mapcycle.txt:/home/steam/css/cstrike/cfg/mapcycle.txt:ro \
  css-server
```

#### Full Production Setup
```bash
docker run -d --net=host \
  --name css-prod \
  --restart unless-stopped \
  -e CSS_HOSTNAME="Pro CSS Server" \
  -e RCON_PASSWORD=verysecret \
  -e STEAM_GSLT=YOUR_TOKEN_HERE \
  -e CSS_MAXPLAYERS=32 \
  -e CSS_TICKRATE=100 \
  -e CSS_BOT_QUOTA=10 \
  -e CSS_DOWNLOADURL=http://content.example.com/css/ \
  -v css-data:/home/steam/css \
  -v ./configs/admins_simple.ini:/home/steam/css/cstrike/addons/sourcemod/configs/admins_simple.ini:ro \
  css-server
```

---

## Phase 5: Dockge Deployment

Dockge-ready configuration for easy management via web UI.

### 5.1 Dockge Stack (compose.yaml)

Place this in your Dockge stacks directory (e.g., `/opt/stacks/css-server/compose.yaml`):

```yaml
version: "3.8"

services:
  css-server:
    image: css-server:latest
    # Or use a pre-built image:
    # image: yourusername/css-server:latest
    container_name: css-server
    restart: unless-stopped

    # Host networking recommended for game servers
    network_mode: host

    environment:
      # === SERVER IDENTITY ===
      CSS_HOSTNAME: ${CSS_HOSTNAME}
      CSS_PASSWORD: ${CSS_PASSWORD}
      RCON_PASSWORD: ${RCON_PASSWORD}
      CSS_CONTACT: ${CSS_CONTACT}
      CSS_REGION: ${CSS_REGION}

      # === NETWORK ===
      CSS_PORT: ${CSS_PORT}
      CSS_MAXPLAYERS: ${CSS_MAXPLAYERS}
      CSS_TICKRATE: ${CSS_TICKRATE}

      # === GAMEPLAY ===
      CSS_MAP: ${CSS_MAP}
      CSS_FRIENDLYFIRE: ${CSS_FRIENDLYFIRE}
      CSS_ALLTALK: ${CSS_ALLTALK}
      CSS_TIMELIMIT: ${CSS_TIMELIMIT}
      CSS_ROUNDTIME: ${CSS_ROUNDTIME}
      CSS_FREEZETIME: ${CSS_FREEZETIME}
      CSS_BUYTIME: ${CSS_BUYTIME}
      CSS_STARTMONEY: ${CSS_STARTMONEY}
      CSS_C4TIMER: ${CSS_C4TIMER}
      CSS_MAXROUNDS: ${CSS_MAXROUNDS}
      CSS_WINLIMIT: ${CSS_WINLIMIT}
      CSS_GRAVITY: ${CSS_GRAVITY}
      CSS_FALLDAMAGE: ${CSS_FALLDAMAGE}

      # === BOTS ===
      CSS_BOT_QUOTA: ${CSS_BOT_QUOTA}
      CSS_BOT_QUOTA_MODE: ${CSS_BOT_QUOTA_MODE}
      CSS_BOT_DIFFICULTY: ${CSS_BOT_DIFFICULTY}
      CSS_BOT_CHATTER: ${CSS_BOT_CHATTER}
      CSS_BOT_JOIN_AFTER_PLAYER: ${CSS_BOT_JOIN_AFTER_PLAYER}
      CSS_BOT_AUTO_VACATE: ${CSS_BOT_AUTO_VACATE}
      CSS_BOT_PREFIX: ${CSS_BOT_PREFIX}

      # === SECURITY ===
      CSS_PURE: ${CSS_PURE}
      CSS_CHEATS: ${CSS_CHEATS}
      CSS_ALLOWUPLOAD: ${CSS_ALLOWUPLOAD}
      CSS_ALLOWDOWNLOAD: ${CSS_ALLOWDOWNLOAD}

      # === FAST DOWNLOAD ===
      CSS_DOWNLOADURL: ${CSS_DOWNLOADURL}
      CSS_MAXFILESIZE: ${CSS_MAXFILESIZE}

      # === STEAM (Required for public servers) ===
      STEAM_GSLT: ${STEAM_GSLT}

    volumes:
      # Full game data persistence
      - ./data/cstrike:/home/steam/css/cstrike

      # OR granular mounts (uncomment as needed):
      # - ./data/cfg:/home/steam/css/cstrike/cfg
      # - ./data/maps:/home/steam/css/cstrike/maps
      # - ./data/sourcemod/plugins:/home/steam/css/cstrike/addons/sourcemod/plugins
      # - ./data/sourcemod/configs:/home/steam/css/cstrike/addons/sourcemod/configs
      # - ./data/sourcemod/data:/home/steam/css/cstrike/addons/sourcemod/data
      # - ./data/logs:/home/steam/css/cstrike/logs
      # - ./data/sound:/home/steam/css/cstrike/sound

    # Health check (optional)
    healthcheck:
      test: ["CMD-SHELL", "pgrep -f srcds_linux || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### 5.2 Dockge Environment File (.env)

Place alongside compose.yaml:

```bash
# ============================================
# COUNTER-STRIKE: SOURCE SERVER CONFIGURATION
# ============================================
# Dockge will show these as editable fields in the UI

# ============ SERVER IDENTITY ============
CSS_HOSTNAME=My Awesome CSS Server
CSS_PASSWORD=
RCON_PASSWORD=CHANGE_THIS_PASSWORD
CSS_CONTACT=admin@example.com
CSS_REGION=255

# ============ NETWORK ============
CSS_PORT=27015
CSS_MAXPLAYERS=24
CSS_TICKRATE=66

# ============ GAMEPLAY ============
CSS_MAP=de_dust2
CSS_FRIENDLYFIRE=0
CSS_ALLTALK=0
CSS_TIMELIMIT=30
CSS_ROUNDTIME=2.5
CSS_FREEZETIME=6
CSS_BUYTIME=90
CSS_STARTMONEY=800
CSS_C4TIMER=45
CSS_MAXROUNDS=0
CSS_WINLIMIT=0
CSS_GRAVITY=800
CSS_FALLDAMAGE=1

# ============ BOTS ============
# Set BOT_QUOTA to 0 for no bots, or a number like 10 to fill empty slots
CSS_BOT_QUOTA=10
CSS_BOT_QUOTA_MODE=fill
CSS_BOT_DIFFICULTY=2
CSS_BOT_CHATTER=minimal
CSS_BOT_JOIN_AFTER_PLAYER=1
CSS_BOT_AUTO_VACATE=1
CSS_BOT_PREFIX=[BOT]

# ============ SECURITY ============
# sv_pure: 0=off, 1=loose, 2=strict (recommended)
CSS_PURE=2
CSS_CHEATS=0
CSS_ALLOWUPLOAD=0
CSS_ALLOWDOWNLOAD=1

# ============ FAST DOWNLOAD ============
# Leave empty if not using a CDN/web server for map downloads
CSS_DOWNLOADURL=
CSS_MAXFILESIZE=64

# ============ STEAM AUTHENTICATION ============
# REQUIRED for public (non-LAN) servers!
# Get your token at: https://steamcommunity.com/dev/managegameservers
# App ID for CS:S is 240 (not 232330)
STEAM_GSLT=
```

### 5.3 Dockge Directory Structure

```
/opt/stacks/css-server/          # Dockge stack directory
├── compose.yaml                  # Docker Compose file
├── .env                          # Environment variables (editable in Dockge UI)
└── data/                         # Persistent data (auto-created)
    └── cstrike/                  # Full game folder mount
        ├── cfg/                  # Server configs
        │   ├── server.cfg
        │   ├── mapcycle.txt
        │   ├── my-server.cfg
        │   ├── banned_user.cfg
        │   └── banned_ip.cfg
        ├── maps/                 # Custom maps
        ├── addons/
        │   ├── metamod/
        │   └── sourcemod/
        │       ├── plugins/      # SourceMod plugins
        │       ├── configs/      # Plugin configs + admins
        │       ├── data/         # Plugin data
        │       └── logs/         # SM logs
        ├── sound/                # Custom sounds
        ├── materials/            # Custom textures
        └── logs/                 # Server logs
```

### 5.4 First Run Setup with Dockge

1. **Create the stack in Dockge**:
   - Click "Compose" in Dockge
   - Name it `css-server`
   - Paste the compose.yaml content
   - Add environment variables from .env

2. **First deployment**:
   - Deploy the stack
   - The container will create the data folder structure
   - Stop the container

3. **Copy default configs** (if using granular volumes):
   ```bash
   # From host, copy configs from container to host
   docker cp css-server:/home/steam/css/cstrike/cfg ./data/
   docker cp css-server:/home/steam/css/cstrike/addons ./data/
   ```

4. **Add your admins**:
   - Edit `./data/cstrike/addons/sourcemod/configs/admins_simple.ini`
   - Add your Steam ID:
     ```
     "STEAM_0:1:12345678" "99:z" // Your Name - full admin
     ```

5. **Customize and restart**:
   - Edit any configs in `./data/`
   - Restart the stack in Dockge

### 5.5 Dockge Tips

- **Environment variables in Dockge UI**: All the `.env` variables will show up as editable fields in Dockge's web interface
- **Logs**: Use Dockge's built-in log viewer to see server console output
- **Updates**: To update the game, exec into container: `docker exec -it css-server ./steamcmd.sh +login anonymous +force_install_dir ./css +app_update 232330 validate +quit`
- **Backups**: The `./data/` folder contains everything - back this up regularly

---

## Phase 6: CI/CD Pipeline

### 5.1 GitHub Actions Workflow

```yaml
name: Build CSS Server Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: css-server:test
          load: true

      - name: Run tests
        run: |
          docker run --rm css-server:test /home/steam/tests/server-test.sh

      - name: Login to DockerHub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Push image
        if: github.event_name != 'pull_request'
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            yourusername/css-server:latest
            yourusername/css-server:${{ github.sha }}
```

---

## Phase 7: Testing

### 7.1 Test Script

```bash
#!/bin/bash
# tests/server-test.sh

set -e

echo "=== CSS Server Test Suite ==="

# Test 1: Server binary exists
echo "[TEST] Checking server binary..."
test -f /home/steam/css/srcds_run || { echo "FAIL: srcds_run not found"; exit 1; }
echo "PASS: Server binary found"

# Test 2: MetaMod installed
echo "[TEST] Checking MetaMod..."
test -d /home/steam/css/cstrike/addons/metamod || { echo "FAIL: MetaMod not found"; exit 1; }
echo "PASS: MetaMod installed"

# Test 3: SourceMod installed
echo "[TEST] Checking SourceMod..."
test -d /home/steam/css/cstrike/addons/sourcemod || { echo "FAIL: SourceMod not found"; exit 1; }
echo "PASS: SourceMod installed"

# Test 4: Configuration files
echo "[TEST] Checking configurations..."
test -f /home/steam/css/cstrike/cfg/server.cfg || { echo "FAIL: server.cfg not found"; exit 1; }
test -f /home/steam/css/cstrike/cfg/mapcycle.txt || { echo "FAIL: mapcycle.txt not found"; exit 1; }
echo "PASS: Configurations found"

# Test 5: Not running as root
echo "[TEST] Checking user..."
[ "$(whoami)" != "root" ] || { echo "FAIL: Running as root"; exit 1; }
echo "PASS: Not running as root"

echo ""
echo "=== All tests passed! ==="
```

---

## Implementation Checklist

### Week 1: Foundation
- [ ] Create project directory structure
- [ ] Write Dockerfile with Ubuntu 22.04 base
- [ ] Install SteamCMD and CS:S
- [ ] Create entrypoint.sh script
- [ ] Test basic server startup

### Week 2: Plugins
- [ ] Research latest MetaMod/SourceMod versions
- [ ] Download and integrate MetaMod
- [ ] Download and integrate SourceMod
- [ ] Install MapChooser Extended
- [ ] Install Quake Sounds
- [ ] Configure plugin settings

### Week 3: Configuration
- [ ] Create comprehensive server.cfg
- [ ] Create mapcycle.txt
- [ ] Set up environment variables
- [ ] Create docker-compose.yml
- [ ] Test all configurations

### Week 4: CI/CD & Polish
- [ ] Create GitHub Actions workflow
- [ ] Write test suite
- [ ] Create documentation (README.md)
- [ ] Test full deployment cycle
- [ ] Push to Docker Hub

---

## Notes

### Version Research Required
Before implementation, verify the latest versions of:
1. MetaMod:Source - check [metamodsource.net](https://www.metamodsource.net/)
2. SourceMod - check [sourcemod.net](https://www.sourcemod.net/)
3. MapChooser Extended - check [AlliedModders forums](https://forums.alliedmods.net/)
4. Quake Sounds - check [AlliedModders forums](https://forums.alliedmods.net/)

### Security Considerations
- Never commit RCON passwords
- Use `.env` files for sensitive data
- Keep `sv_pure 2` enabled for competitive play
- Regularly update base image and plugins

### Customization Points
Users can customize without rebuilding:
- `my-server.cfg` - Custom server settings
- `mapcycle.txt` - Map rotation
- `admins_simple.ini` - Admin access
- Environment variables - Server name, passwords, etc.
