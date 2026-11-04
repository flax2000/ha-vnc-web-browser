FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# 1. Install lean dependencies
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    matchbox-window-manager \
    chromium \
    x11-xserver-utils \
    xauth \
    jq \
    dbus-x11 \
    ca-certificates \
    xdotool \
    libgl1-mesa-dri \
    libglapi-mesa \
    libosmesa6 \
    libegl-dev \
    libgles-dev \
    libvulkan-dev \
    python3 \
    python3-pip \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Simplified User Setup
RUN groupadd -g 109 render || true && \
    useradd -m -s /bin/bash vnc_user && \
    usermod -aG video vnc_user && \
    usermod -aG render vnc_user || true

# 3. Set up environment
USER vnc_user
RUN mkdir -p /home/vnc_user/.vnc

# 4. Copy files and set permissions
USER root
COPY startup.sh /home/vnc_user/startup.sh
COPY run_vnc.sh /home/vnc_user/run_vnc.sh
COPY chromium_preferences.json /home/vnc_user/chromium_preferences.json
COPY xstartup /home/vnc_user/.vnc/xstartup

RUN chown -R vnc_user:vnc_user /home/vnc_user && \
    chmod +x /home/vnc_user/startup.sh /home/vnc_user/run_vnc.sh /home/vnc_user/.vnc/xstartup

WORKDIR /home/vnc_user
ENV USER=vnc_user

LABEL \
    io.hass.name="VNC Web Browser" \
    io.hass.description="Display multiple web pages through VNC" \
    io.hass.type="addon" \
    io.hass.version="0.13.63" \
    io.hass.arch="aarch64|amd64|armhf|armv7"

EXPOSE 5901-5908 8080

USER root
CMD ["/home/vnc_user/startup.sh"]