#!/usr/bin/env bash
# Vigilante (corre en tmux, sesion "watch"):
#  - autobackup cada BACKUP_EVERY minutos (backup en vivo)
#  - obedece el comando "stop" escrito en r2:BUCKET/CMD (apaga limpio + push)
source "$(dirname "$0")/env.sh"
require_r2

BACKUP_EVERY="${BACKUP_EVERY:-30}"   # minutos
POLL=30                              # segundos entre revisiones
LAST_BACKUP="$(date +%s)"
echo "[watch] iniciado como $WHO. Autobackup cada ${BACKUP_EVERY} min."

while true; do
  sleep "$POLL"

  CMD="$(rclone cat "r2:$BUCKET/CMD" 2>/dev/null || true)"
  if [ "$CMD" = "stop" ]; then
    echo "[watch] comando STOP recibido"
    rclone deletefile "r2:$BUCKET/CMD" 2>/dev/null || true
    bash "$ROOT/scripts/stop.sh" && bash "$ROOT/scripts/push.sh"
    exit 0
  fi

  NOW="$(date +%s)"
  if tmux has-session -t mc 2>/dev/null && [ $((NOW - LAST_BACKUP)) -ge $((BACKUP_EVERY * 60)) ]; then
    echo "[watch] autobackup..."
    bash "$ROOT/scripts/push.sh" --live || echo "[watch] el backup fallo (se reintenta en el siguiente ciclo)"
    LAST_BACKUP="$(date +%s)"
  fi
done
