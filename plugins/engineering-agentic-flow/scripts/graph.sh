#!/usr/bin/env bash
#
# Construye o actualiza el grafo de conocimiento del repo con graphify. Es
# OBLIGATORIO para el flujo: si graphify no esta instalado o falla, termina con
# error y el flujo se detiene.
#
#   graph.sh [--global] [--html] [--relabel]
#
#   --global   agrega o actualiza este repo en el grafo global (~/.graphify/global-graph.json)
#              para consultar entre repos (por ejemplo, la app web y su API).
#   --html     genera las vistas para el navegador: graph.html (red interactiva) y
#              GRAPH_TREE.html (arbol por carpetas), y las abre si hay un navegador.
#   --relabel  vuelve a nombrar todas las comunidades con el LLM.
#
# Modos:
#   completo  codigo (AST local) + documentacion (.md, ADR, CLAUDE.md, PDF, docx)
#             con extraccion semantica, y comunidades con nombre. Necesita un LLM.
#   codigo    solo AST local: sin LLM y sin costo. Comunidades sin nombre.
#
# El LLM se elige en este orden:
#   1. GRAPHIFY_BACKEND (claude-cli, claude, gemini, openai, deepseek, ollama…;
#      "none" fuerza el modo codigo).
#   2. El CLI `claude` si esta instalado: usa tu suscripcion de Claude, sin API key.
#      Modelo: GRAPHIFY_CLAUDE_CLI_MODEL (por defecto haiku, el mas barato).
#   3. Una API key en el entorno (graphify la detecta).
# Configuracion opcional en ~/.config/graphify/env (lineas "export VAR=valor").
#
# La primera construccion en modo completo de un repo grande puede tardar varios
# minutos; las siguientes son incrementales (solo lo que cambio).
#
# Salida: 0 grafo listo · 1 fallo al generar · 4 falta graphify o Python
#
set -uo pipefail

GLOBAL=0; HTML=0; RELABEL=0
for a in "$@"; do
  case "$a" in
    --global)  GLOBAL=1 ;;
    --html)    HTML=1 ;;
    --relabel) RELABEL=1 ;;
    *) echo "opcion desconocida: $a" >&2; exit 2 ;;
  esac
done

if ! command -v graphify >/dev/null 2>&1; then
  echo "GRAFO: REQUERIDO y no instalado. Instala con: uv tool install graphifyy"
  exit 4
fi

PY=""
for p in python3 python py; do
  # En Windows, "python3" puede ser el alias de la Microsoft Store que no ejecuta nada.
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done
if [ -z "$PY" ]; then
  echo "GRAFO: falta Python 3 (graphify tambien lo necesita)"; exit 4
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2
OUT="graphify-out/graph.json"
LOG="$ROOT/.agentflow/logs/graph.log"; mkdir -p "$(dirname "$LOG")"

# El grafo es local: que no aparezca como archivo nuevo en git ni en verify.sh.
EXCLUDE="$(git rev-parse --git-path info/exclude 2>/dev/null || true)"
if [ -n "$EXCLUDE" ] && ! grep -qxF 'graphify-out/' "$EXCLUDE" 2>/dev/null; then
  mkdir -p "$(dirname "$EXCLUDE")" && echo 'graphify-out/' >> "$EXCLUDE"
fi

# --- Modo y LLM -------------------------------------------------------------
CONF="${GRAPHIFY_ENV_FILE:-$HOME/.config/graphify/env}"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

MODE="completo"
case "$(printf '%s' "${GRAPHIFY_BACKEND:-}" | tr '[:upper:]' '[:lower:]')" in
  none|off|disable|disabled) MODE="codigo" ;;
  "")
    if command -v claude >/dev/null 2>&1; then
      export GRAPHIFY_BACKEND="claude-cli"
    elif [ -z "${ANTHROPIC_API_KEY:-}${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}${OPENAI_API_KEY:-}${DEEPSEEK_API_KEY:-}${MOONSHOT_API_KEY:-}" ]; then
      MODE="codigo"
    fi ;;
esac
export GRAPHIFY_CLAUDE_CLI_MODEL="${GRAPHIFY_CLAUDE_CLI_MODEL:-haiku}"
BACKEND="${GRAPHIFY_BACKEND:-auto}"

# Lo que nunca se manda al LLM: imagenes y multimedia (en apps moviles son cientos
# de assets), y los artefactos del propio flujo.
EXCLUDES=()
for pat in '*.png' '*.jpg' '*.jpeg' '*.gif' '*.webp' '*.svg' '*.ico' \
           '*.mp4' '*.mov' '*.webm' '*.mkv' '*.avi' '*.m4v' '*.mp3' '*.wav' '*.m4a' '*.ogg' \
           '.agentflow/' 'graphify-out/'; do
  EXCLUDES+=(--exclude "$pat")
done

# Marca propia del estado del repo (HEAD + cambios sin commit + modo): graphify
# update no refresca built_at_commit, asi que no sirve para saber si esta al dia.
STAMP_FILE="graphify-out/.agentflow-stamp"
stamp() {
  { echo "modo=$MODE"
    git rev-parse HEAD 2>/dev/null
    git status --porcelain --untracked-files=normal -- . ':!graphify-out' ':!.agentflow' 2>/dev/null
    git diff HEAD -- . ':!graphify-out' ':!.agentflow' 2>/dev/null; } | git hash-object --stdin
}

node_count() {
  "$PY" -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["nodes"]))' "$OUT" 2>/dev/null
}

has_labels() {
  "$PY" -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
real = [v for k, v in d.items() if isinstance(v, str) and v.strip() and v != "Community " + str(k)]
sys.exit(0 if real else 1)' graphify-out/.graphify_labels.json 2>/dev/null
}

fail() {
  rm -f "$STAMP_FILE"
  echo "GRAFO: $1 (log: ${LOG#"$ROOT"/})"
  tail -n 15 "$LOG" | sed 's/^/    | /'
  exit 1
}

# --- Construir o actualizar -------------------------------------------------
STAMP="$(stamp)"
: >"$LOG"
ACTION="al dia"
if [ -z "$(node_count)" ]; then
  ACTION="construido"
  rm -f "$OUT" "$STAMP_FILE"   # graphify no reconstruye sobre un graph.json ilegible
fi
if [ "$ACTION" = "construido" ] || [ "$(cat "$STAMP_FILE" 2>/dev/null)" != "$STAMP" ]; then
  [ "$ACTION" = "al dia" ] && ACTION="actualizado"
  if [ "$MODE" = "completo" ]; then
    # Incremental: el AST sale de cache y solo los documentos nuevos o cambiados van al LLM.
    echo "GRAFO: $ACTION en modo completo (LLM: $BACKEND)… la primera vez puede tardar varios minutos"
    graphify extract . "${EXCLUDES[@]}" >>"$LOG" 2>&1 || fail "fallo la extraccion"
  elif [ "$ACTION" = "construido" ]; then
    echo "GRAFO: construyendo en modo codigo…"
    graphify extract . --code-only "${EXCLUDES[@]}" >>"$LOG" 2>&1 || fail "fallo la extraccion"
  else
    graphify update . >>"$LOG" 2>&1 || fail "fallo la actualizacion"
  fi
  [ -n "$(node_count)" ] || fail "el grafo quedo vacio"
fi

# --- Comunidades con nombre (solo modo completo) -------------------------------
LABELS="sin nombre (modo codigo)"
if [ "$MODE" = "completo" ]; then
  if [ "$RELABEL" = 1 ] || ! has_labels; then
    # Primera vez o pedido explicito: el LLM nombra todas las comunidades.
    graphify label . >>"$LOG" 2>&1 || fail "fallo al nombrar comunidades"
  elif [ "$ACTION" != "al dia" ]; then
    # Reusa los nombres guardados; las comunidades nuevas toman el nombre de su nodo central.
    graphify cluster-only . --no-viz >>"$LOG" 2>&1 || fail "fallo al reagrupar comunidades"
  fi
  if has_labels; then LABELS="con nombre"; else LABELS="sin nombre (el LLM no devolvio nombres)"; fi
fi

echo "$STAMP" > "$STAMP_FILE"
echo "GRAFO: $ACTION — $(node_count) nodos — modo $MODE — comunidades $LABELS — $OUT"
grep -h 'syntax errors' "$LOG" 2>/dev/null | sed 's/^ */AVISO: /' | head -3

if [ "$GLOBAL" = 1 ]; then
  TAG="$(basename "$ROOT")"
  if graphify global add "$OUT" --as "$TAG" >>"$LOG" 2>&1; then
    echo "GLOBAL: '$TAG' en $(graphify global path 2>/dev/null | sed 's/^Global graph: //')"
  else
    echo "GLOBAL: fallo al agregar '$TAG' (log: ${LOG#"$ROOT"/})"
  fi
fi

if [ "$HTML" = 1 ]; then
  if graphify export html --graph "$OUT" >>"$LOG" 2>&1 \
     && graphify tree --graph "$OUT" --output graphify-out/GRAPH_TREE.html --label "$(basename "$ROOT")" >>"$LOG" 2>&1; then
    echo "VISTA: $ROOT/graphify-out/graph.html (red) · $ROOT/graphify-out/GRAPH_TREE.html (arbol)"
    case "$(uname -s)" in
      Darwin) open graphify-out/graph.html graphify-out/GRAPH_TREE.html ;;
      MINGW*|MSYS*|CYGWIN*) cmd.exe //c start "" "graphify-out\\graph.html" >/dev/null 2>&1
                            cmd.exe //c start "" "graphify-out\\GRAPH_TREE.html" >/dev/null 2>&1 ;;
      *) if command -v xdg-open >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
           xdg-open graphify-out/graph.html >/dev/null 2>&1 &
         fi ;;
    esac
  else
    echo "VISTA: fallo al generar (log: ${LOG#"$ROOT"/})"
  fi
fi
exit 0
