#!/usr/bin/env bash
#
# Estado de una corrida de /eng-flow, en un archivo plano que cualquier runtime
# (Claude Code, Antigravity) y cualquier modelo puede leer y continuar.
#
#   state.sh init <id> <carril> <base>      crea el estado (no sobrescribe uno existente)
#   state.sh set <id> clave=valor [...]     actualiza claves
#   state.sh get <id> <clave>               imprime un valor
#   state.sh show <id>                      imprime el estado y las ultimas lineas del log
#   state.sh log <id> <etapa> <resultado> [runtime/modelo]
#   state.sh latest                         id de la corrida mas reciente
#
# Claves usadas por el flujo: lane, base, branch, stage, subtasks_total,
# subtasks_done (ej. 1,2), loops_verify, loops_review, loops_security,
# gate_design (na|pendiente|aprobado), last_verdict, note, runtime.
#
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DIR="$ROOT/.agentflow/state"
mkdir -p "$DIR"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

runtime_default() {
  if [ -n "${AGENTFLOW_RUNTIME:-}" ]; then printf '%s' "$AGENTFLOW_RUNTIME"
  elif [ -n "${CLAUDECODE:-}" ]; then printf 'claude'
  else printf 'otro'; fi
}

die() { echo "state.sh: $*" >&2; exit 2; }

valid_id() { case "$1" in ""|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac; }

# set_kv <archivo> <clave> <valor>: reemplaza o agrega, de forma atomica.
set_kv() {
  local f="$1" tmp
  tmp="$(mktemp "$f.XXXXXX")" || die "no se pudo crear archivo temporal"
  K="$2" V="$3" awk '
    BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"]; done = 0 }
    index($0, k "=") == 1 { print k "=" v; done = 1; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  init)
    id="${1:-}"; lane="${2:-}"; base="${3:-}"
    valid_id "$id" || die "id invalido (usa letras, numeros, . _ -)"
    [ -n "$lane" ] && [ -n "$base" ] || die "uso: init <id> <carril> <base>"
    f="$DIR/$id.state"
    if [ -f "$f" ]; then echo "ya existe: $f (usa /eng-resume para continuar)"; exit 3; fi
    # El estado es local de esta corrida: que no aparezca como archivo nuevo en git.
    EXCL="$(git rev-parse --git-path info/exclude 2>/dev/null || true)"
    if [ -n "$EXCL" ] && ! grep -qxF '.agentflow/state/' "$EXCL" 2>/dev/null; then
      mkdir -p "$(dirname "$EXCL")" && echo '.agentflow/state/' >> "$EXCL"
    fi
    {
      echo "id=$id"
      echo "lane=$lane"
      echo "base=$base"
      echo "branch=feature/$id"
      echo "stage=triage"
      echo "gate_design=na"
      echo "loops_verify=0"
      echo "loops_review=0"
      echo "loops_security=0"
      echo "subtasks_done="
      echo "runtime=$(runtime_default)"
      echo "started=$(now)"
      echo "updated=$(now)"
    } > "$f"
    printf '%s\t%s\t%s\t%s\n' "$(now)" "$(runtime_default)" "triage" "carril=$lane" >> "$DIR/$id.log"
    echo "estado creado: $f"
    ;;
  set)
    id="${1:-}"; shift || true
    valid_id "$id" || die "id invalido"
    f="$DIR/$id.state"; [ -f "$f" ] || die "no existe estado para $id (corre init)"
    [ $# -gt 0 ] || die "uso: set <id> clave=valor [...]"
    for kv in "$@"; do
      case "$kv" in *=*) ;; *) die "esperaba clave=valor, recibi: $kv" ;; esac
      k="${kv%%=*}"; v="${kv#*=}"
      case "$k" in ""|*[!A-Za-z0-9_]*) die "clave invalida: $k" ;; esac
      set_kv "$f" "$k" "$v"
    done
    set_kv "$f" updated "$(now)"
    ;;
  get)
    id="${1:-}"; k="${2:-}"
    valid_id "$id" || die "id invalido"
    f="$DIR/$id.state"; [ -f "$f" ] || exit 1
    awk -v k="$k" 'index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' "$f"
    ;;
  show)
    id="${1:-}"
    valid_id "$id" || die "id invalido"
    f="$DIR/$id.state"; [ -f "$f" ] || die "no existe estado para $id"
    cat "$f"
    if [ -f "$DIR/$id.log" ]; then echo "--- log (ultimas 12)"; tail -n 12 "$DIR/$id.log"; fi
    ;;
  log)
    id="${1:-}"; stage="${2:-}"; result="${3:-}"; rt="${4:-$(runtime_default)}"
    valid_id "$id" || die "id invalido"
    [ -n "$stage" ] || die "uso: log <id> <etapa> <resultado> [runtime/modelo]"
    printf '%s\t%s\t%s\t%s\n' "$(now)" "$rt" "$stage" "$result" >> "$DIR/$id.log"
    ;;
  latest)
    # shellcheck disable=SC2012
    f="$(ls -t "$DIR"/*.state 2>/dev/null | head -n 1)"
    [ -n "$f" ] || exit 1
    basename "$f" .state
    ;;
  *)
    sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
