#!/bin/bash
set -e

chown -R openclaw:openclaw /data
chmod 700 /data

if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi

rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew

# Optional virtual desktop stack for browser automation.
# Enable with ENABLE_NOVNC=true.
if [ "${ENABLE_NOVNC:-false}" = "true" ]; then
  export DISPLAY="${DISPLAY:-:99}"
  export VNC_PORT="${VNC_PORT:-5900}"
  export NOVNC_PORT="${NOVNC_PORT:-6080}"
  export VNC_RESOLUTION="${VNC_RESOLUTION:-1920x1080x24}"

  mkdir -p /tmp/.X11-unix /run/dbus
  chown -R openclaw:openclaw /tmp/.X11-unix

  dbus-daemon --system --fork >/tmp/dbus.log 2>&1 || true

  gosu openclaw Xvfb "$DISPLAY" -screen 0 "$VNC_RESOLUTION" -ac -nolisten tcp >/tmp/xvfb.log 2>&1 &
  sleep 1
  gosu openclaw fluxbox >/tmp/fluxbox.log 2>&1 &
  gosu openclaw x11vnc \
    -display "$DISPLAY" \
    -rfbport "$VNC_PORT" \
    -forever \
    -shared \
    -nopw \
    >/tmp/x11vnc.log 2>&1 &
  websockify --web=/usr/share/novnc "$NOVNC_PORT" "127.0.0.1:$VNC_PORT" >/tmp/novnc.log 2>&1 &

  # Optional: auto-launch Chromium for manual login/cookie management.
  if [ "${NOVNC_AUTOSTART_CHROMIUM:-true}" = "true" ]; then
    gosu openclaw chromium \
      --no-sandbox \
      --disable-dev-shm-usage \
      --disable-gpu \
      >/tmp/chromium.log 2>&1 &
  fi
fi

exec gosu openclaw node src/server.js
