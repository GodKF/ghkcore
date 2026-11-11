#!/usr/bin/env bash
# Baja el servidor desde R2 y toma el LOCK. Uso: bash scripts/pull.sh [--force]
source "$(dirname "$0")/env.sh"
require_r2

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

if tmux has-session -t mc 2>/dev/null; then
  echo "ERROR: el servidor esta corriendo aqui. Ejecuta scripts/stop.sh primero."
  exit 1
fi

# 1. Revisar LOCK
CUR="$(rclone cat "r2:$BUCKET/LOCK" 2>/dev/null || true)"
if [ -n "$CUR" ] && [[ "$CUR" != "$WHO "* ]] && [ "$FORCE" -eq 0 ]; then
  echo "BLOQUEADO: el servidor lo tiene otro Codespace:"
  echo "  $CUR"
  echo "Si ya no esta activo y sabes que el mundo esta subido, usa: bash scripts/pull.sh --force"
  exit 1
fi

# 2. Parte liviana (mods, config, etc.)
mkdir -p "$SERVER_DIR"
echo ">> Bajando archivos livianos..."
rclone sync "r2:$BUCKET/server" "$SERVER_DIR" "${LIGHT_EXCLUDES[@]}" --progress

# 3. Mundo: el backup mas reciente
LAST="$(rclone lsf "r2:$BUCKET/mundos/" --files-only 2>/dev/null | sort | tail -n 1 || true)"
if [ -z "$LAST" ]; then
  echo "AVISO: no hay mundos en r2:$BUCKET/mundos/ (se generara uno nuevo al iniciar)."
else
  echo ">> Bajando mundo: $LAST"
  TMP="$(mktemp -d)"
  rclone copy "r2:$BUCKET/mundos/$LAST" "$TMP" --progress
  mkdir -p "$TMP/x"
  tar -xzf "$TMP/$LAST" -C "$TMP/x"
  rm -rf "$SERVER_DIR/world"
  mv "$TMP/x/world" "$SERVER_DIR/world"
  rm -rf "$TMP"
fi

# 4. Tomar el LOCK
echo "$WHO $(date -u +%FT%TZ)" | rclone rcat "r2:$BUCKET/LOCK"
echo "OK. Tienes el LOCK. Inicia con: bash scripts/start.sh"
