#!/usr/bin/env bash
# Inicia playit y el servidor en sesiones de fondo. Uso: bash scripts/start.sh
source "$(dirname "$0")/env.sh"

command -v tmux >/dev/null || { echo "Falta tmux"; exit 1; }
if tmux has-session -t mc 2>/dev/null; then
  echo "El servidor ya esta corriendo (tmux attach -t mc)."
  exit 0
fi

JAR="$(ls "$SERVER_DIR"/forge-*.jar 2>/dev/null | head -n 1 || true)"
[ -n "$JAR" ] || { echo "ERROR: no encuentro forge-*.jar en $SERVER_DIR"; exit 1; }

# playit (mantiene la IP fija si usas la misma key)
if [ -n "${PLAYIT_SECRET:-}" ]; then
  if ! pgrep -x playit >/dev/null; then
    nohup playit --secret "$PLAYIT_SECRET" > "$ROOT/playit.log" 2>&1 &
    echo ">> playit iniciado (log: playit.log)"
  fi
else
  echo "AVISO: no hay PLAYIT_SECRET; el server arranca sin tunel."
fi

tmux new-session -d -s mc -c "$SERVER_DIR" \
  "java -Xms${MC_RAM} -Xmx${MC_RAM} -jar $(basename "$JAR") nogui"
echo ">> Servidor iniciado con ${MC_RAM}. Consola: tmux attach -t mc  (salir sin cerrar: Ctrl+B y luego D)"

# vigilante: autobackup y apagado remoto
if ! tmux has-session -t watch 2>/dev/null; then
  if [ -n "${R2_ACCESS_KEY_ID:-}" ]; then
    tmux new-session -d -s watch -c "$ROOT" "bash scripts/watch.sh"
    echo ">> watch iniciado (autobackup cada ${BACKUP_EVERY:-30} min). Ver: tmux attach -t watch"
  else
    echo "AVISO: sin secrets de R2, no se inicia el autobackup."
  fi
fi
