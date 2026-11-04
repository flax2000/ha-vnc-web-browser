#!/bin/bash

# 1. System Cleanup (Must be done as root)
rm -rf /tmp/.X*-lock /tmp/.X11-unix
mkdir -p /run/dbus
chown vnc_user:vnc_user /run/dbus

# 2. Start System D-Bus
dbus-daemon --system --fork --address=unix:path=/run/dbus/system_bus_socket

# 3. Start Session D-Bus and capture variables
# We do this here so we can pass them to the vnc_user
DBUS_OUTPUT=$(dbus-launch --sh-syntax)
eval "$(echo "$DBUS_OUTPUT" | sed "s/'//g")"
export DBUS_SESSION_BUS_ADDRESS
export DBUS_SESSION_BUS_PID

# 4. Handle VNC Password
config=$(cat /data/options.json)
vnc_password=$(echo "$config" | jq -r '.vnc_password // empty')

mkdir -p /home/vnc_user/.vnc
if [ -n "$vnc_password" ]; then
    echo "$vnc_password" | vncpasswd -f > /home/vnc_user/.vnc/passwd
    chmod 600 /home/vnc_user/.vnc/passwd
else
    rm -f /home/vnc_user/.vnc/passwd
fi
chown -R vnc_user:vnc_user /home/vnc_user/.vnc

# 5. Prepare Data Directories
displays=$(echo "$config" | jq -c '.displays[]')
while IFS= read -r display; do
    port=$(echo "$display" | jq -r '.port')
    display_number=$((port - 5900))
    mkdir -p "/data/chromium-data-$display_number"
    chown -R vnc_user:vnc_user "/data/chromium-data-$display_number"
done <<< "$displays"

# 6. Switch to vnc_user and run the VNC script
# We export the DBUS variable into the su command to ensure Chromium sees it
exec su - vnc_user -c "export DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS; /home/vnc_user/run_vnc.sh '$config'"