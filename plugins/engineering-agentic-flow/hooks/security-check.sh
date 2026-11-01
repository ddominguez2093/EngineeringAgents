#!/usr/bin/env bash
#
# Guardrail PreToolUse del plugin engineering-agentic-flow.
# Bloquea comandos destructivos y el acceso a archivos de secretos ANTES de ejecutarse.
# Recibe el evento JSON por stdin y responde con permissionDecision=deny.
#
# Lee el JSON con `jq` o, si no esta (comun en Windows), con Python. Si no hay
# ninguno de los dos, deja pasar pero avisa por stderr.

set -euo pipefail

PY=""
for p in python3 python py; do
  # En Windows, "python3" puede ser el alias de la Microsoft Store que no ejecuta nada.
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done

if ! command -v jq >/dev/null 2>&1 && [ -z "$PY" ]; then
  echo "engineering-agentic-flow: ni jq ni python disponibles; guardrail de seguridad deshabilitado." >&2
  exit 0
fi

INPUT="$(cat)"

# field <ruta.json> [alternativa]: primer valor no vacio de las rutas dadas.
field() {
  if command -v jq >/dev/null 2>&1; then
    local q=".$1"; [ $# -gt 1 ] && q="$q // .$2"
    printf '%s' "$INPUT" | jq -r "$q // empty"
  else
    printf '%s' "$INPUT" | "$PY" -c '
import json, sys
d = json.load(sys.stdin)
for path in sys.argv[1:]:
    v = d
    for k in path.split("."):
        v = v.get(k) if isinstance(v, dict) else None
    if v:
        print(v); break
' "$@"
  fi
}

deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  else
    "$PY" -c 'import json, sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))' "$1"
  fi
  exit 0
}

TOOL="$(field tool_name)"

# Archivos de secretos, por nombre de archivo o carpeta. No se bloquea codigo
# fuente que solo mencione "credentials" en su nombre (CredentialsRepository.kt).
SECRET_RE='(^|/)(\.env(\.[^/]*)?|id_(rsa|dsa|ecdsa|ed25519)|[^/]*\.(pem|p12|pfx|jks|keystore|mobileprovision)|credentials(\.json)?|secrets?\.(json|ya?ml|properties)|google-services\.json|GoogleService-Info\.plist|\.netrc|\.npmrc)$|(^|/)\.(aws|ssh|gnupg)/'
ALLOW_RE='(^|/)\.env\.(example|sample|template|dist)$'

is_secret() {
  if printf '%s' "$1" | grep -qE "$ALLOW_RE"; then return 1; fi
  printf '%s' "$1" | grep -qE "$SECRET_RE"
}

# rm recursivo cuyo objetivo es la raiz o el home (con o sin comillas, con o sin /*).
RM_RE='(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(--[[:space:]]+)?["'"'"']?(/|~|\$HOME|\$\{HOME\})/?\*?["'"'"']?([[:space:]]|;|&|$)'

case "$TOOL" in
  Bash)
    CMD="$(field tool_input.command)"
    if printf '%s' "$CMD" | grep -qE "$RM_RE"; then
      deny "Comando destructivo bloqueado (rm recursivo sobre / o el home). Requiere aprobacion humana."
    fi
    if printf '%s' "$CMD" | grep -qE '\b(curl|wget)\b[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh)\b'; then
      deny "Descarga y ejecucion directa (curl | sh) bloqueada."
    fi
    if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push\b.*(--force|[[:space:]]-f\b)' \
       && printf '%s' "$CMD" | grep -qE '\b(main|master|develop)\b'; then
      deny "Force-push a main/master/develop bloqueado."
    fi
    if printf '%s' "$CMD" | grep -qE '\b(chmod|chown)[[:space:]]+-R[[:space:]]+777'; then
      deny "Permisos 777 recursivos bloqueados."
    fi
    ;;
  Write|Edit|Read)
    # Windows entrega rutas con "\"; se normalizan a "/" para las expresiones.
    FILE="$(field tool_input.file_path tool_input.path | tr '\\' '/')"
    if [ -n "$FILE" ] && is_secret "$FILE"; then
      deny "Acceso a archivo de secretos bloqueado ($FILE). Los agentes no leen ni escriben credenciales."
    fi
    ;;
esac

exit 0
