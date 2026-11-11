#!/usr/bin/env bash
# Vincula playit a tu cuenta (se hace UNA sola vez) y localiza la secret key.
# Uso: bash scripts/playit-setup.sh
set -uo pipefail

command -v playit >/dev/null 2>&1 || { echo "playit no esta instalado. Ejecuta: bash .devcontainer/setup.sh"; exit 1; }

echo "=== Vincular playit ==="
echo "1) Va a arrancar el agente y mostrara un enlace de 'claim'."
echo "2) Abrelo en tu navegador, inicia sesion en playit.gg y aprueba el agente."
echo "3) Cuando diga que esta conectado, pulsa Ctrl+C para volver aqui."
echo
trap ':' INT
playit
trap - INT

echo
echo "=== Buscando la secret key guardada ==="
FILES="$(find "$HOME" -maxdepth 4 -name 'playit*.toml' 2>/dev/null | sort -u || true)"
if [ -z "$FILES" ]; then
  echo "No encontre ningun playit*.toml. Si el agente conecto bien, mira la key en"
  echo "playit.gg > Agents, o busca con: grep -r secret ~/.config 2>/dev/null"
  exit 1
fi

echo "$FILES" | while read -r f; do
  echo "Archivo: $f"
  grep -i "secret" "$f" || true
done
echo
echo "Guarda ese valor en un lugar seguro. NO lo pegues en el chat ni lo subas al repo."
echo "Cuando quieras compartirlo entre cuentas, ponlo como secret PLAYIT_SECRET en"
echo "GitHub > Settings > Codespaces > Secrets."
echo
echo "Falta un paso en playit.gg: crear un tunel 'Minecraft Java' hacia 127.0.0.1:25565"
echo "(asi la IP publica apunta a tu servidor)."
