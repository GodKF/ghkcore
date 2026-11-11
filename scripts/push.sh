#!/usr/bin/env bash
# Sube el servidor a R2.
# Uso: bash scripts/push.sh [--keep-lock] [--live] [--force]
#   --live       backup con el server ENCENDIDO (save-off / save-all flush); implica --keep-lock
#   --keep-lock  no suelta el LOCK al terminar
source "$(dirname "$0")/env.sh"
require_r2

KEEP_LOCK=0; FORCE=0; LIVE=0
for a in "$@"; do
  case "$a" in
    --keep-lock) KEEP_LOCK=1 ;;
    --force) FORCE=1 ;;
    --live) LIVE=1; KEEP_LOCK=1 ;;
  esac
done

RUNNING=0
if tmux has-session -t mc 2>/dev/null; then RUNNING=1; fi
if [ "$RUNNING" -eq 1 ] && [ "$LIVE" -eq 0 ]; then
  echo "ERROR: el servidor sigue encendido. Ejecuta scripts/stop.sh primero (o usa --live)."
  exit 1
fi
if [ "$RUNNING" -eq 0 ]; then LIVE=0; fi

CUR="$(rclone cat "r2:$BUCKET/LOCK" 2>/dev/null || true)"
if [ -n "$CUR" ] && [[ "$CUR" != "$WHO "* ]] && [ "$FORCE" -eq 0 ]; then
  echo "BLOQUEADO: el LOCK es de otro Codespace: $CUR"
  echo "No subo para no pisar su mundo. (--force si sabes lo que haces)"
  exit 1
fi

[ -d "$SERVER_DIR/world" ] || { echo "ERROR: no existe $SERVER_DIR/world"; exit 1; }

# 1. Liviano
echo ">> Subiendo archivos livianos..."
rclone sync "$SERVER_DIR" "r2:$BUCKET/server" "${LIGHT_EXCLUDES[@]}" --progress

# 2. Mundo comprimido
NAME="mundo-$(date +%F-%H%M).tar.gz"
echo ">> Comprimiendo mundo -> $NAME"
if [ "$LIVE" -eq 1 ]; then
  trap 'tmux send-keys -t mc "save-on" Enter 2>/dev/null || true' EXIT
  tmux send-keys -t mc "save-off" Enter
  tmux send-keys -t mc "save-all flush" Enter
  sleep 10
fi
# tar devuelve 1 si algun archivo cambio mientras lo leia (aviso, no error)
tar -czf "/tmp/$NAME" -C "$SERVER_DIR" world || {
  rc=$?
  [ "$rc" -eq 1 ] || { echo "ERROR: fallo tar (codigo $rc)"; exit 1; }
}
if [ "$LIVE" -eq 1 ]; then
  tmux send-keys -t mc "save-on" Enter
  trap - EXIT
fi
rclone copy "/tmp/$NAME" "r2:$BUCKET/mundos/" --s3-chunk-size 64M --progress

# 3. Verificar y rotar (solo si la subida quedo bien)
if [ -n "$(rclone lsf "r2:$BUCKET/mundos/$NAME" 2>/dev/null)" ]; then
  rm -f "/tmp/$NAME"
  echo ">> Rotando: conservo los ultimos $KEEP_BACKUPS mundos"
  rclone lsf "r2:$BUCKET/mundos/" --files-only | sort | head -n "-$KEEP_BACKUPS" | \
    while read -r f; do
      [ -n "$f" ] && rclone deletefile "r2:$BUCKET/mundos/$f"
    done
else
  echo "ERROR: no pude verificar la subida. NO borro nada y NO suelto el LOCK."
  exit 1
fi

# 4. Soltar LOCK
if [ "$KEEP_LOCK" -eq 0 ]; then
  rclone deletefile "r2:$BUCKET/LOCK" 2>/dev/null || true
  echo "OK. LOCK liberado: otro Codespace ya puede hacer pull."
  tmux kill-session -t watch 2>/dev/null || true
else
  echo "OK. Subido (conservas el LOCK)."
fi
