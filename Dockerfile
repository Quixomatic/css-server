# Counter-Strike: Source Dedicated Server
# Modern Docker image with MetaMod + SourceMod support

FROM ubuntu:22.04

LABEL maintainer="admin@example.com"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.description="Counter-Strike: Source Dedicated Server with SourceMod"
LABEL org.label-schema.url="https://github.com/yourusername/css-server"

# Build arguments for versioning
ARG METAMOD_VERSION=1.12
ARG SOURCEMOD_VERSION=1.12

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
# - 64-bit libraries for srcds (CS:S got 64-bit support Feb 2025)
# - 32-bit libraries kept for SteamCMD compatibility
# - wget, curl, ca-certificates: downloading
# - unzip: extracting plugins
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        unzip \
        locales \
        # 64-bit libraries for CS:S
        libstdc++6 \
        libc6 \
        libcurl4 \
        # 32-bit libraries for SteamCMD
        lib32gcc-s1 \
        lib32stdc++6 \
        lib32z1 \
        libc6-i386 \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create non-root user for security
RUN useradd -m -d /home/steam -s /bin/bash steam
WORKDIR /home/steam

# Switch to steam user for installation
USER steam

# Install SteamCMD
RUN mkdir -p /home/steam/steamcmd && \
    cd /home/steam/steamcmd && \
    wget -qO- https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xvz

# Update SteamCMD first (required before downloading apps)
RUN /home/steam/steamcmd/steamcmd.sh +quit

# Install Counter-Strike: Source Dedicated Server
# App ID 232330 = CS:S Dedicated Server
# Retry up to 3 times as SteamCMD can be flaky
RUN for i in 1 2 3; do \
        /home/steam/steamcmd/steamcmd.sh \
            +force_install_dir /home/steam/css \
            +login anonymous \
            +app_update 232330 validate \
            +quit \
        && break || sleep 5; \
    done && test -f /home/steam/css/srcds_run

# Create Steam SDK symlinks for both 32-bit (SteamCMD) and 64-bit (CS:S)
RUN mkdir -p /home/steam/.steam/sdk32 /home/steam/.steam/sdk64 && \
    ln -s /home/steam/steamcmd/linux32/steamclient.so /home/steam/.steam/sdk32/steamclient.so && \
    ln -s /home/steam/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so

# Install MetaMod:Source 1.12 (64-bit - CS:S got 64-bit support Feb 2025)
RUN echo "Installing MetaMod:Source ${METAMOD_VERSION} (64-bit)..." && \
    METAMOD_URL=$(curl -sL "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/mmsource-latest-linux") && \
    wget -q "https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/${METAMOD_URL}" -O /tmp/metamod.tar.gz && \
    tar -xzf /tmp/metamod.tar.gz -C /home/steam/css/cstrike && \
    rm /tmp/metamod.tar.gz && \
    echo "MetaMod installed: ${METAMOD_URL}"

# Install SourceMod 1.12 (64-bit)
RUN echo "Installing SourceMod ${SOURCEMOD_VERSION} (64-bit)..." && \
    SM_URL=$(curl -sL "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/sourcemod-latest-linux") && \
    wget -q "https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/${SM_URL}" -O /tmp/sourcemod.tar.gz && \
    tar -xzf /tmp/sourcemod.tar.gz -C /home/steam/css/cstrike && \
    rm /tmp/sourcemod.tar.gz && \
    echo "SourceMod installed: ${SM_URL}"

# Create MetaMod VDF loader (64-bit path for CS:S Feb 2025 update)
RUN echo '"Plugin"' > /home/steam/css/cstrike/addons/metamod.vdf && \
    echo '{' >> /home/steam/css/cstrike/addons/metamod.vdf && \
    echo '    "file" "../cstrike/addons/metamod/bin/linux64/server"' >> /home/steam/css/cstrike/addons/metamod.vdf && \
    echo '}' >> /home/steam/css/cstrike/addons/metamod.vdf

# Copy configuration files
COPY --chown=steam:steam dist/cstrike/cfg/ /home/steam/css/cstrike/cfg/
COPY --chown=steam:steam dist/cstrike/addons/sourcemod/configs/ /home/steam/css/cstrike/addons/sourcemod/configs/
COPY --chown=steam:steam dist/cstrike/addons/metamod.vdf /home/steam/css/cstrike/addons/metamod.vdf

# Create backup of default files for volume initialization
# This allows the entrypoint to populate empty mounted volumes with defaults
RUN mkdir -p /home/steam/css-defaults && \
    cp -r /home/steam/css/cstrike/cfg /home/steam/css-defaults/ && \
    cp -r /home/steam/css/cstrike/addons /home/steam/css-defaults/ && \
    cp -r /home/steam/css/cstrike/maps /home/steam/css-defaults/

# Copy entrypoint script
COPY --chown=steam:steam scripts/entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh

# Copy test script
COPY --chown=steam:steam tests/ /home/steam/tests/
RUN chmod +x /home/steam/tests/*.sh 2>/dev/null || true

# === ENVIRONMENT VARIABLES ===

# Server Identity
ENV CSS_HOSTNAME="Counter-Strike Source Server"
# CSS_PASSWORD and RCON_PASSWORD should be set at runtime, not in image
ENV CSS_CONTACT=""
ENV CSS_REGION="255"

# Network
ENV CSS_PORT="27015"
ENV CSS_MAXPLAYERS="24"
ENV CSS_TICKRATE="66"
ENV CSS_MAXRATE="0"
ENV CSS_MINRATE="20000"
ENV CSS_MAXUPDATERATE="100"
ENV CSS_MINUPDATERATE="30"

# Gameplay
ENV CSS_MAP="de_dust2"
ENV CSS_FRIENDLYFIRE="0"
ENV CSS_ALLTALK="0"
ENV CSS_TIMELIMIT="30"
ENV CSS_ROUNDTIME="2.5"
ENV CSS_FREEZETIME="6"
ENV CSS_BUYTIME="90"
ENV CSS_STARTMONEY="800"
ENV CSS_C4TIMER="45"
ENV CSS_MAXROUNDS="0"
ENV CSS_WINLIMIT="0"
ENV CSS_GRAVITY="800"
ENV CSS_FALLDAMAGE="1"

# Bots
ENV CSS_BOT_QUOTA="0"
ENV CSS_BOT_QUOTA_MODE="fill"
ENV CSS_BOT_DIFFICULTY="2"
ENV CSS_BOT_CHATTER="minimal"
ENV CSS_BOT_JOIN_AFTER_PLAYER="1"
ENV CSS_BOT_AUTO_VACATE="1"
ENV CSS_BOT_PREFIX="[BOT]"

# Security
ENV CSS_PURE="2"
ENV CSS_CHEATS="0"
ENV CSS_ALLOWUPLOAD="0"
ENV CSS_ALLOWDOWNLOAD="1"
ENV CSS_RCON_BANPENALTY="30"
ENV CSS_RCON_MAXFAILURES="10"

# Fast Download
ENV CSS_DOWNLOADURL=""
ENV CSS_MAXFILESIZE="64"

# Logging
ENV CSS_LOG="on"
ENV CSS_LOGBANS="1"
ENV CSS_LOGDETAIL="3"

# Steam
ENV STEAM_GSLT=""

# Expose ports
# 27015/tcp - RCON
# 27015/udp - Game traffic
# 27020/udp - Client port
# 27005/udp - HLTV
# 26901/udp - NAT traversal
EXPOSE 27015/tcp 27015/udp 27020/udp 27005/udp 26901/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f srcds_linux || exit 1

ENTRYPOINT ["/home/steam/entrypoint.sh"]
