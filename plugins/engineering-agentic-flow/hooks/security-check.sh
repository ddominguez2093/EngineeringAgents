#!/usr/bin/env bash
#
# Guardrail PreToolUse del plugin engineering-agentic-flow.
# Bloquea comandos destructivos y el acceso a archivos de secretos ANTES de ejecutarse.
# Recibe el evento JSON por stdin y responde con permissionDecision=deny.
#
# Requiere `jq`. Si no esta, deja pasar pero avisa por stderr.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "engineering-agentic-flow: jq no encontrado; guardrail de seguridad deshabilitado." >&2
  exit 0
fi

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

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
    CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
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
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
    if [ -n "$FILE" ] && is_secret "$FILE"; then
      deny "Acceso a archivo de secretos bloqueado ($FILE). Los agentes no leen ni escriben credenciales."
    fi
    ;;
esac

exit 0
