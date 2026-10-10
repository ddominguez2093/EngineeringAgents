#!/usr/bin/env bash
#
# Escaneres de seguridad sobre el cambio: secretos (gitleaks), SAST (semgrep) y
# dependencias (trivy). Imprime una linea por escaner; solo en los hallazgos
# agrega la cola del log. Una herramienta ausente se reporta, nunca cuenta como limpia.
#
#   scan.sh [base]
#
set -uo pipefail

BASE="${1:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS="$ROOT/.agentflow/logs"; mkdir -p "$LOGS"
TAIL_LINES="${SCAN_TAIL:-60}"

if [ -z "$BASE" ]; then
  for b in main master develop; do
    git rev-parse --verify -q "$b" >/dev/null 2>&1 && { BASE="$b"; break; }
  done
fi

FINDINGS=0; MISSING=0

run() { # nombre, comando...
  local name="$1"; shift
  local log="$LOGS/scan-$name.log"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "AUSENTE   $name (instalalo: brew install $name)"; MISSING=$((MISSING+1)); return
  fi
  if "$@" >"$log" 2>&1; then
    echo "LIMPIO    $name"
  else
    FINDINGS=$((FINDINGS+1))
    echo "HALLAZGOS $name — log completo: ${log#"$ROOT"/}"
    tail -n "$TAIL_LINES" "$log" | sed 's/^/    | /'
  fi
}

# Secretos: solo los commits del cambio si hay base; si no, el arbol completo.
if [ -n "$BASE" ] && [ "$(git rev-parse "$BASE")" != "$(git rev-parse HEAD)" ]; then
  run gitleaks gitleaks git --no-banner --redact --log-opts="$BASE..HEAD" .
else
  run gitleaks gitleaks dir --no-banner --redact .
fi

# SAST: OWASP + secretos, y las reglas Flutter si hay codigo Dart.
SEMGREP_ARGS=(scan --quiet --error --config p/owasp-top-ten --config p/secrets)
RULES=""
for c in "$HERE/semgrep-flutter.yml" "$HERE/../security/semgrep-flutter.yml"; do
  [ -f "$c" ] && { RULES="$c"; break; }
done
if [ -n "$RULES" ] && git ls-files '*.dart' | grep -q .; then SEMGREP_ARGS+=(--config "$RULES"); fi
[ -n "$BASE" ] && SEMGREP_ARGS+=(--baseline-commit "$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")")
run semgrep semgrep "${SEMGREP_ARGS[@]}"

# Dependencias con vulnerabilidades altas o criticas.
run trivy trivy fs --quiet --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .

if [ "$FINDINGS" -gt 0 ]; then echo "RESULTADO: hallazgos en $FINDINGS escaner(es)"; exit 1; fi
if [ "$MISSING" -gt 0 ]; then echo "RESULTADO: incompleto ($MISSING escaner(es) ausentes)"; exit 3; fi
echo "RESULTADO: limpio"
