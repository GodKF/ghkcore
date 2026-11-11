#!/usr/bin/env bash
# Apaga el servidor limpio (guarda el mundo) y detiene playit.
source "$(dirname "$0")/env.sh"

if tmux has-session -t mc 2>/dev/null; then
  echo ">> Enviando 'stop'..."
  tmux send-keys -t mc "stop" Enter
  for i in $(seq 1 120); do
    tmux has-session -t mc 2>/dev/null || break
    sleep 1
  done
  tmux has-session -t mc 2>/dev/null && { echo "ERROR: no se apago en 120s"; exit 1; }
  echo ">> Servidor apagado."
else
  echo "El servidor no estaba corriendo."
fi

# Importante: dos agentes playit con la misma key chocan.
pkill -x playit 2>/dev/null && echo ">> playit detenido." || true
