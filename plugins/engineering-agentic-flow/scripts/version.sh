#!/usr/bin/env bash
#
# Compara la version instalada de engineering-agentic-flow con la de GitHub (main).
#
#   version.sh
#
# Salida: 0 al dia · 1 hay una version mas nueva en GitHub · 2 no se pudo comparar
#
set -uo pipefail

REPO="ddominguez2093/EngineeringAgents"
PLUGIN_PATH="plugins/engineering-agentic-flow"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Claude Code define CLAUDE_PLUGIN_ROOT; si el script corre desde .agentflow/ o desde
# un checkout, se usa la carpeta del plugin que lo contiene (o la copia de sync).
ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$ROOT" ] || [ ! -f "$ROOT/.claude-plugin/plugin.json" ]; then
  ROOT="$(cd "$HERE/.." && pwd)"
fi

# Corriendo desde .agentflow/ (copia generada por sync-antigravity.sh): el plugin de
# origen es el que registro .sync-meta.
META="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.agentflow/.sync-meta"
if [ ! -f "$ROOT/.claude-plugin/plugin.json" ] && [ -f "$META" ]; then
  P="$(sed -n 's/^plugin_path=//p' "$META")"
  [ -f "$P/.claude-plugin/plugin.json" ] && ROOT="$P"
fi

ver_of() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1; }

LOCAL_VER=""
[ -f "$ROOT/.claude-plugin/plugin.json" ] && LOCAL_VER="$(ver_of < "$ROOT/.claude-plugin/plugin.json")"

# Copia generada por sync-antigravity.sh (si existe): version y commit con que se genero.
SYNC="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.agentflow/.sync-meta"
SYNC_VER=""; SYNC_SHA=""
if [ -f "$SYNC" ]; then
  SYNC_VER="$(sed -n 's/^plugin_version=//p' "$SYNC")"
  SYNC_SHA="$(sed -n 's/^source_commit=//p' "$SYNC")"
fi

# Commit instalado por Claude Code (si lo registra).
INST_SHA=""
IP="$HOME/.claude/plugins/installed_plugins.json"
PY=""
for p in python3 python; do command -v "$p" >/dev/null 2>&1 && { PY="$p"; break; }; done
if [ -f "$IP" ] && [ -n "$PY" ]; then
  INST_SHA="$("$PY" -I - "$IP" <<'EOF' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
def walk(o, key=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from walk(v, key + "/" + k)
        if "gitCommitSha" in o and "engineering-agentic-flow" in key:
            yield o["gitCommitSha"]
    elif isinstance(o, list):
        for i in o:
            yield from walk(i, key)
for sha in walk(d):
    print(sha); break
EOF
)"
fi

# Lo que hay en GitHub.
REMOTE_VER=""; REMOTE_SHA=""
RAW=""
if command -v gh >/dev/null 2>&1; then
  RAW="$(gh api "repos/$REPO/contents/$PLUGIN_PATH/.claude-plugin/plugin.json" --jq .content 2>/dev/null | base64 --decode 2>/dev/null || true)"
  REMOTE_SHA="$(gh api "repos/$REPO/commits/main" --jq .sha 2>/dev/null || true)"
fi
if [ -z "$RAW" ] && command -v curl >/dev/null 2>&1; then
  RAW="$(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/$PLUGIN_PATH/.claude-plugin/plugin.json" 2>/dev/null || true)"
fi
if ! printf '%s' "$REMOTE_SHA" | grep -qE '^[0-9a-f]{40}$' && command -v curl >/dev/null 2>&1; then
  REMOTE_SHA="$(curl -fsSL -H 'Accept: application/vnd.github.sha' "https://api.github.com/repos/$REPO/commits/main" 2>/dev/null || true)"
fi
# Solo se acepta un SHA completo; cualquier otra cosa (un error de la API) se descarta.
printf '%s' "$REMOTE_SHA" | grep -qE '^[0-9a-f]{40}$' || REMOTE_SHA=""
printf '%s' "$RAW" | grep -q '"version"' || RAW=""
[ -n "$RAW" ] && REMOTE_VER="$(printf '%s' "$RAW" | ver_of)"

short() { printf '%s' "${1:0:7}"; }

# Los scripts de .agentflow/ son copias: se quedan viejos cuando el plugin se actualiza.
DRIFT=""
AFDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.agentflow"
if [ -d "$AFDIR" ]; then
  for f in "$ROOT"/scripts/*.sh; do
    b="$(basename "$f")"
    [ "$b" = "sync-antigravity.sh" ] && continue
    if [ ! -f "$AFDIR/$b" ]; then DRIFT="$DRIFT $b(falta)"
    elif ! cmp -s "$f" "$AFDIR/$b"; then DRIFT="$DRIFT $b"; fi
  done
fi

echo "Plugin en uso:       ${LOCAL_VER:-?}   ($ROOT)"
[ -n "$INST_SHA" ] && echo "Commit instalado:    $(short "$INST_SHA")"
[ -n "$SYNC_VER" ] && echo "Copia Antigravity:   $SYNC_VER   (commit $(short "$SYNC_SHA"))"
echo "GitHub main:         ${REMOTE_VER:-no disponible}   ${REMOTE_SHA:+(commit $(short "$REMOTE_SHA"))}"

if [ -n "$DRIFT" ]; then
  echo "SCRIPTS DE ESTE REPO desactualizados respecto al plugin en uso:$DRIFT"
  echo "                     -> corre /eng-context (o scripts/sync-antigravity.sh) para refrescarlos."
fi

if [ -z "$REMOTE_VER" ]; then
  echo "RESULTADO: no se pudo consultar GitHub (sin red o sin gh/curl)."; exit 2
fi

# El commit es la prueba exacta; la version es la que decide si Claude Code actualiza.
cur_sha="${INST_SHA:-$SYNC_SHA}"
if [ -n "$cur_sha" ] && [ -n "$REMOTE_SHA" ] && [ "$cur_sha" != "$REMOTE_SHA" ]; then
  if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
    echo "RESULTADO: hay commits nuevos en GitHub con la misma version ($REMOTE_VER)."
    echo "           Claude Code no los baja hasta que 'version' cambie en plugin.json."
  else
    echo "RESULTADO: desactualizado ($LOCAL_VER -> $REMOTE_VER)."
  fi
  echo "ACTUALIZAR: claude plugin marketplace update bitstream-agents && claude plugin update engineering-agentic-flow@bitstream-agents"
  echo "            luego /reload-plugins (o sesion nueva). Antigravity: repite scripts/sync-antigravity.sh."
  exit 1
fi
if [ "$LOCAL_VER" != "$REMOTE_VER" ]; then
  echo "RESULTADO: desactualizado ($LOCAL_VER -> $REMOTE_VER)."
  echo "ACTUALIZAR: claude plugin marketplace update bitstream-agents && claude plugin update engineering-agentic-flow@bitstream-agents"
  exit 1
fi
if [ -z "$cur_sha" ] || [ -z "$REMOTE_SHA" ]; then
  echo "RESULTADO: misma version ($LOCAL_VER); no pude comparar commits (confirma con 'claude plugin list')."
  exit 0
fi
echo "RESULTADO: al dia."
