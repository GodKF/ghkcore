# Servidor Minecraft Forge 1.16.5 portable (Codespaces + Cloudflare R2)

El mundo y los mods NO viven en este repo: viven en un bucket de Cloudflare R2.
El repo solo trae los scripts y la configuracion del Codespace.

## Secrets (una sola vez por cuenta)
GitHub > Settings > Codespaces > Secrets (dale acceso a este repo):

| Secret | Valor |
|---|---|
| `R2_ACCESS_KEY_ID` | Access Key ID del token de R2 |
| `R2_SECRET_ACCESS_KEY` | Secret del token de R2 |
| `R2_ENDPOINT` | `https://TU_ACCOUNT_ID.r2.cloudflarestorage.com` |
| `PLAYIT_SECRET` | Agent secret de playit (misma para todos = misma IP) |

Opcionales: `R2_BUCKET` (por defecto `mc-server`), `MC_RAM` (por defecto `4G`), `KEEP_BACKUPS` (por defecto `3`).

## Flujo
```bash
bash scripts/pull.sh    # baja server + ultimo mundo y toma el LOCK
bash scripts/start.sh   # inicia playit y el server (consola: tmux attach -t mc)
bash scripts/stop.sh    # apaga limpio
bash scripts/push.sh    # sube todo, rota backups y suelta el LOCK
```

## Reglas
- Solo UN Codespace con el server encendido a la vez (el LOCK lo protege).
- Siempre `stop.sh` y luego `push.sh` antes de dejar el Codespace.
- Si un Codespace murio sin hacer push (inactividad), el LOCK queda puesto:
  revisa que el mundo en R2 sea el que quieres y usa `pull.sh --force`.
- Nunca subas claves al repo.

## Autobackup y apagado remoto
`start.sh` tambien inicia un vigilante (`tmux attach -t watch`) que:
- sube un backup en vivo cada `BACKUP_EVERY` minutos (por defecto 30; secret opcional)
- si escribes `stop` en el archivo `CMD` del bucket, apaga el server, hace push y suelta el LOCK

## Si el Codespace se apaga solo por inactividad
El disco se conserva. Al reabrirlo/arrancarlo: `bash scripts/pull.sh && bash scripts/start.sh`.
Como el LOCK sigue siendo de ese mismo Codespace, `pull.sh` NO sobrescribe el mundo local.
Lo maximo que se pierde es lo ocurrido desde el ultimo autobackup si el disco se perdiera.

## Maquina
El devcontainer pide 4 nucleos / 16 GB. Cuenta doble contra la cuota gratis de horas.
