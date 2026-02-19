# Changelog

## 1.0.0

### Features
- Base CS:S dedicated server Docker image (Ubuntu 22.04)
- SteamCMD + CS:S dedicated server (64-bit, App ID 232330)
- 64-bit binary workaround: copies srcds_linux64 and libsteam_api.so from TF2 (Valve Issue #7057)
- MetaMod:Source 1.12 (64-bit)
- SourceMod 1.12 (64-bit)
- SM-RIPExt 1.3.2 (REST in Pawn) extension for HTTP/JSON support
- Volume auto-population: empty mounted volumes get populated with defaults from image
- Non-root container running as `steam` user (UID 1000)
- Entrypoint script with environment variable to server.cfg mapping
- Default server configs (server.cfg, mapcycle.txt, etc.)
- Default SourceMod configs (admins, databases, etc.)
- Health check via pgrep for srcds_linux64
- Docker Hub and GHCR publishing via GitHub Actions

---
