#!/usr/bin/env bash
#
# Construye o actualiza el grafo de codigo del repo con graphify (solo AST local:
# sin LLM, sin costo de tokens). Opcional: si graphify no esta instalado, lo dice
# y termina sin error para que el flujo siga con Grep/Glob.
#
#   graph.sh [--global]
#
#   --global  agrega o actualiza este repo en el grafo global (~/.graphify/global-graph.json)
#             para consultar entre repos (por ejemplo, la app web y su API).
#
set -uo pipefail

GLOBAL=0
for a in "$@"; do
  case "$a" in
    --global) GLOBAL=1 ;;
    *) echo "opcion desconocida: $a" >&2; exit 2 ;;
  esac
done

if ! command -v graphify >/dev/null 2>&1; then
  echo "GRAFO: no disponible (instala: uv tool install graphifyy). Se usa Grep/Glob."
  exit 0
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

# Marca propia del estado del codigo (HEAD + cambios sin commit): graphify update
# no refresca built_at_commit, asi que no sirve para saber si el grafo esta al dia.
STAMP_FILE="graphify-out/.agentflow-stamp"
stamp() {
  { git rev-parse HEAD 2>/dev/null
    git status --porcelain --untracked-files=normal -- . ':!graphify-out' ':!.agentflow' 2>/dev/null
    git diff HEAD -- . ':!graphify-out' ':!.agentflow' 2>/dev/null; } | git hash-object --stdin
}

node_count() {
  python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["nodes"]))' "$OUT" 2>/dev/null
}

STAMP="$(stamp)"
STATUS=0
if [ -z "$(node_count)" ]; then
  ACTION="construido"
  rm -f "$OUT" "$STAMP_FILE"   # graphify no reconstruye sobre un graph.json ilegible
  graphify extract . --code-only >"$LOG" 2>&1 || STATUS=$?
elif [ "$(cat "$STAMP_FILE" 2>/dev/null)" != "$STAMP" ]; then
  ACTION="actualizado"
  graphify update . >"$LOG" 2>&1 || STATUS=$?
else
  ACTION="al dia"; : >"$LOG"
fi

if [ "$STATUS" != 0 ] || [ -z "$(node_count)" ]; then
  rm -f "$STAMP_FILE"
  echo "GRAFO: fallo al generar (log: ${LOG#"$ROOT"/}). Se usa Grep/Glob."
  tail -n 15 "$LOG" | sed 's/^/    | /'
  exit 0
fi

echo "$STAMP" > "$STAMP_FILE"
NODES="$(node_count)"
echo "GRAFO: $ACTION — $NODES nodos — $OUT"
grep -h 'syntax errors' "$LOG" 2>/dev/null | sed 's/^ */AVISO: /' | head -3

if [ "$GLOBAL" = 1 ]; then
  TAG="$(basename "$ROOT")"
  if graphify global add "$OUT" --as "$TAG" >>"$LOG" 2>&1; then
    echo "GLOBAL: '$TAG' en $(graphify global path 2>/dev/null | sed 's/^Global graph: //')"
  else
    echo "GLOBAL: fallo al agregar '$TAG' (log: ${LOG#"$ROOT"/})"
  fi
fi
