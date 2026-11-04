#!/bin/bash

# Ensure config is provided
config="$1"
if [ -z "$config" ]; then
    echo "Error: No configuration provided."
    exit 1
fi

# 1. Environment Setup
export XDG_RUNTIME_DIR=/tmp
export MALLOC_ARENA_MAX=2

# 2. Extract global configurations
displays=$(echo "$config" | jq -c '.displays[]')
# Extract frame_rate from configuration, default to 5 if not found
frame_rate=$(echo "$config" | jq -r '.frame_rate // 5')

# 3. Loop through each display
while IFS= read -r display; do
    url=$(echo "$display" | jq -r '.url')
    resolution=$(echo "$display" | jq -r '.resolution')
    port=$(echo "$display" | jq -r '.port')
    depth=$(echo "$display" | jq -r '.depth // 24')
    view_only=$(echo "$display" | jq -r '.view_only // false')
    browser_args=$(echo "$display" | jq -r '.browser_args // ""')
    startup_commands=$(echo "$display" | jq -r '.startup_commands // "key Escape mousemove 150 40 sleep 0.5 click 1 sleep 0.5 click 1"')
    display_number=$((port - 5900))

    width=$(echo "$resolution" | cut -d'x' -f1)
    height=$(echo "$resolution" | cut -d'x' -f2)

# 4. Start VNC Server with Dynamic Frame Rate & RealVNC Fixes
    vnc_opts="-geometry ${width}x${height} -depth ${depth} -rfbport $port -alwaysshared -nocursor -comparefb 0 -FrameRate $frame_rate"
    [ "$view_only" = "true" ] && vnc_opts="$vnc_opts -viewonly"

    if [ ! -f "/home/vnc_user/.vnc/passwd" ]; then
        echo "Starting VNC server on :$display_number (No Password) at ${frame_rate} FPS"
        Xvnc :$display_number $vnc_opts -SecurityTypes None &
    else
        echo "Starting VNC server on :$display_number (With Password) at ${frame_rate} FPS"
        Xvnc :$display_number $vnc_opts -SecurityTypes VncAuth -rfbauth /home/vnc_user/.vnc/passwd &
    fi

    # Wait for X server to stabilize
    sleep 3

    # 5. Set background and Window Manager
    DISPLAY=:$display_number xsetroot -solid black
    DISPLAY=:$display_number matchbox-window-manager -use_titlebar no &
    sleep 1

    # 6. Prepare Data Directory
    USER_DATA_DIR="/data/chromium-data-$display_number"
    mkdir -p "$USER_DATA_DIR/Default"
    
    # Wipe temporary bloat to save space 24/7
    rm -rf "$USER_DATA_DIR/Default/Cache"/*
    rm -rf "$USER_DATA_DIR/Default/Code Cache"/*
    rm -rf "$USER_DATA_DIR/Default/GPUCache"/*

    # 7. Force 'Normal' exit status to block "Restore Pages" bubble
    if [ -f "$USER_DATA_DIR/Default/Preferences" ]; then
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$USER_DATA_DIR/Default/Preferences"
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$USER_DATA_DIR/Default/Preferences"
    fi


# 8. Launch Chromium - Kiosk Engine Highly Optimized 24/7 Kiosk Engine
# Launch Chromium - Kiosk Engine
    (while true; do
        DISPLAY=:$display_number chromium \
            --new-window \
            --kiosk \
            --app="$url" \
            --window-size=${width},${height} \
            --user-data-dir="$USER_DATA_DIR" \
            --no-first-run \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-gpu \
            --disable-software-rasterizer-fallback \
            --use-gl=disabled \
            "$browser_args" &
        
        # Vänta tills Chromium hunnit ladda
        sleep 5
        
        # Kör konfigurerade startup-kommandon via xdotool
        DISPLAY=:$display_number xdotool key Escape $startup_commands
        
        # Vänta på att processen dör innan loopen startar om
        wait $!
        sleep 3
    done) &
    echo "Chromium Kiosk started for $url on Port $port"

done <<< "$displays"



# 10. Start an Advanced Control Server
echo "Starting Control Server on port 8080..."
cat << 'EOF' > /tmp/control.py
import http.server
import socketserver
import subprocess
import re
import json

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Clean path to prevent hidden character mismatches
        clean_path = self.path.strip()
        
        # Matches action_<display_num> (e.g., restart_1, pause_2, redraw_1)
        match_standard = re.match(r'^/(pause|resume|redraw|restart)_(\d+)$', clean_path)
        
        # Matches click_<display_num>_<X>x<Y> (e.g., click_1_500x500)
        match_click = re.match(r'^/click_(\d+)_(\d+)x(\d+)$', clean_path)
        
        if match_standard:
            action, display_num = match_standard.groups()
            
            if action == 'pause':
                cmd = f'pkill -STOP -f "chromium.*--user-data-dir=/data/chromium-data-{display_num}"'
                msg = f'Chromium on Display :{display_num} Pausing...\n'
            elif action == 'resume':
                cmd = f'pkill -CONT -f "chromium.*--user-data-dir=/data/chromium-data-{display_num}"'
                msg = f'Chromium on Display :{display_num} Resuming...\n'
            elif action == 'redraw':
                cmd = f'DISPLAY=:{display_num} xdotool key ctrl+F5 ; sleep 3 ; DISPLAY=:{display_num} xdotool key Escape'
                msg = f'Fullständig omladdning och klick utfört på Display :{display_num}\n'
            elif action == 'restart':
                cmd = f'pkill -f "chromium.*--user-data-dir=/data/chromium-data-{display_num}"'
                msg = f'chromium on Display :{display_num} Restarting...\n'
           
            self.send_response(200)
            self.end_headers()
            self.wfile.write(msg.encode())
            subprocess.Popen(cmd, shell=True)

        elif match_click:
            # Extract display number, X, and Y coordinates
            display_num, x, y = match_click.groups()
            
            # Formulate the xdotool command to move to coordinates and click
            cmd = f'DISPLAY=:{display_num} xdotool mousemove {x} {y} click 1'
            msg = f'Clicking at {x}x{y} on Display :{display_num}\n'
            
            self.send_response(200)
            self.end_headers()
            self.wfile.write(msg.encode())
            subprocess.Popen(cmd, shell=True)
            
        elif clean_path == '/pause':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'All Chromium Instances Pausing...\n')
            subprocess.Popen('pkill -STOP chromium', shell=True)
            
        elif clean_path == '/resume':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'All Chromium Instances Resuming...\n')
            subprocess.Popen('pkill -CONT chromium', shell=True)
            
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(f'Endpoint Not Found: {clean_path}\n'.encode())

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", 8080), Handler) as httpd:
    httpd.serve_forever()
EOF

python3 /tmp/control.py &

# Keep the process alive for Docker
tail -f /dev/null
```[cite: 2]