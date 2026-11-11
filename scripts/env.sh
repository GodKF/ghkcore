#!/usr/bin/env bash
# Configuracion comun. Se carga con: source "$(dirname "$0")/env.sh"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT/server"
BUCKET="${R2_BUCKET:-mc-server}"
KEEP_BACKUPS="${KEEP_BACKUPS:-3}"      # cuantos mundos comprimidos conservar
MC_RAM="${MC_RAM:-4G}"                 # RAM para el servidor
WHO="${GITHUB_USER:-user}@${CODESPACE_NAME:-local}"   # identifica quien tiene el LOCK

require_r2() {
  for v in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT; do
    if [ -z "${!v:-}" ]; then
      echo "ERROR: falta el secret $v (GitHub > Settings > Codespaces > Secrets)"
      exit 1
    fi
  done
  export RCLONE_CONFIG_R2_TYPE=s3
  export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
  export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
  export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  export RCLONE_CONFIG_R2_ENDPOINT="$R2_ENDPOINT"
  export RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true
}

# Archivos que NO viajan en el sync liviano
LIGHT_EXCLUDES=(--exclude "world/**" --exclude "logs/**" --exclude "crash-reports/**" \
                --exclude "*.tmp" --exclude "playit*" --exclude ".gitkeep")
