#!/usr/bin/env bash
# Sube el servidor a R2 y suelta el LOCK. Uso: bash scripts/push.sh [--keep-lock] [--force]
source "$(dirname "$0")/env.sh"
require_r2

KEEP_LOCK=0; FORCE=0
for a in "$@"; do
  [ "$a" = "--keep-lock" ] && KEEP_LOCK=1
  [ "$a" = "--force" ] && FORCE=1
done

if tmux has-session -t mc 2>/dev/null; then
  echo "ERROR: el servidor sigue encendido. Ejecuta scripts/stop.sh primero."
  exit 1
fi

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
tar -czf "/tmp/$NAME" -C "$SERVER_DIR" world
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
else
  echo "OK. Subido (conservas el LOCK)."
fi
