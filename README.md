# Counter-Strike: Source Dedicated Server

Modern Docker image for Counter-Strike: Source with MetaMod and SourceMod pre-installed.

## Quick Start (Pull from Registry)

```bash
# Just run it - pulls from GitHub Container Registry
docker run -d --net=host \
  -e CSS_HOSTNAME="My Server" \
  -e RCON_PASSWORD="changeme" \
  -e CSS_BOT_QUOTA=10 \
  -v ./data/cstrike:/home/steam/css/cstrike \
  ghcr.io/quiomatic/css-server:latest
```

Or use Docker Compose / Dockge - see `compose.yaml`.

## Build Locally (Optional)

```bash
# 1. Copy environment file and configure
cp .env.example .env

# 2. Build and run
docker compose up -d --build

# 3. View logs
docker compose logs -f
```

## Features

- Ubuntu 22.04 LTS base
- MetaMod:Source 1.12.x (auto-downloaded)
- SourceMod 1.12.x (auto-downloaded)
- 40+ configurable environment variables
- Volume mounts for easy customization
- Non-root user for security
- Health checks
- Dockge compatible

## Configuration

All settings can be configured via environment variables in `.env` or `compose.yaml`.

### Key Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `CSS_HOSTNAME` | Counter-Strike Source Server | Server name |
| `CSS_PASSWORD` | (empty) | Join password |
| `RCON_PASSWORD` | (empty) | Admin password |
| `CSS_MAP` | de_dust2 | Starting map |
| `CSS_MAXPLAYERS` | 24 | Max players |
| `CSS_TICKRATE` | 66 | Server tickrate |
| `CSS_BOT_QUOTA` | 0 | Number of bots |
| `STEAM_GSLT` | (empty) | Required for public servers |

See `.env.example` for all options.

## Volume Mounts

Mount individual folders for full control:

```yaml
volumes:
  - ./cfg:/home/steam/css/cstrike/cfg           # Server configs
  - ./addons:/home/steam/css/cstrike/addons     # MetaMod + SourceMod + plugins
  - ./maps:/home/steam/css/cstrike/maps         # Custom maps
  - ./sound:/home/steam/css/cstrike/sound       # Custom sounds
  - ./materials:/home/steam/css/cstrike/materials # Textures
  - ./models:/home/steam/css/cstrike/models     # Models
  - ./logs:/home/steam/css/cstrike/logs         # Server logs
```

On first run, empty volumes are automatically populated with defaults.

### Volume Permissions

The container runs as user `steam` (UID 1000). Set permissions on your host:

```bash
# Set ownership to match container user
sudo chown -R 1000:1000 /path/to/your/stack/

# Set directory permissions (755 = rwxr-xr-x)
sudo chmod -R 755 /path/to/your/stack/
```

| Folder | Needs Write | Description |
|--------|-------------|-------------|
| `cfg/` | Yes | Configs, ban lists, env_settings.cfg |
| `addons/` | Yes | SourceMod data, logs, plugin storage |
| `maps/` | No | Custom map files (.bsp) |
| `sound/` | No | Custom sounds |
| `materials/` | No | Textures, sprays |
| `models/` | No | Player/weapon models |
| `logs/` | Yes | Server logs |

## Adding Admins

Edit `data/cstrike/addons/sourcemod/configs/admins_simple.ini`:

```ini
"STEAM_0:1:12345678"    "99:z"    ; YourName - Root Admin
```

## Adding Plugins

1. Download `.smx` file from [AlliedModders](https://forums.alliedmods.net/)
2. Copy to `data/cstrike/addons/sourcemod/plugins/`
3. Restart server or use RCON: `sm plugins refresh`

## Commands

```bash
make build      # Build image
make run        # Start server
make stop       # Stop server
make logs       # View logs
make shell      # Shell access
make test       # Run tests
make update     # Update CS:S
```

## Public Server Setup

1. Get a Game Server Login Token at https://steamcommunity.com/dev/managegameservers
2. Use App ID `240` (not 232330)
3. Set `STEAM_GSLT=your_token` in `.env`

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 27015 | TCP/UDP | Game + RCON |
| 27020 | UDP | Client |
| 27005 | UDP | HLTV |
| 26901 | UDP | NAT |

## License

MIT
