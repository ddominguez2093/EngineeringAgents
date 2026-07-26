#!/usr/bin/env bash
#
# PreToolUse guardrail del plugin engineering-agentic-flow.
# Bloquea comandos destructivos y el acceso a secretos ANTES de ejecutarse.
# Recibe el evento JSON por stdin; bloquea con permissionDecision=deny (exit 0).
#
# Requiere `jq`. Si no esta, deja pasar (no rompe el flujo) pero avisa por stderr.

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

case "$TOOL" in
  Bash)
    CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
    if printf '%s' "$CMD" | grep -qE 'rm[[:space:]]+-rf[[:space:]]+/($|[^t])'; then
      deny "Comando destructivo bloqueado (rm -rf en ruta del sistema). Requiere aprobacion humana."
    fi
    if printf '%s' "$CMD" | grep -qE '\b(curl|wget)\b[^|]*\|[[:space:]]*(sh|bash)'; then
      deny "Descarga y ejecucion directa (curl|sh) bloqueada por seguridad."
    fi
    if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]].*--force.*\b(main|master)\b|git[[:space:]]+push[[:space:]].*\b(main|master)\b.*--force'; then
      deny "Force-push a main/master bloqueado."
    fi
    if printf '%s' "$CMD" | grep -qE '\b(chmod|chown)[[:space:]]+-R[[:space:]]+777'; then
      deny "Permisos 777 recursivos bloqueados."
    fi
    ;;
  Write|Edit|Read)
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
    if printf '%s' "$FILE" | grep -qE '(\.env($|\.)|id_rsa|\.pem$|credentials|/\.aws/|/\.ssh/)'; then
      deny "Acceso a archivo de secretos bloqueado ($FILE). Los agentes no leen ni escriben credenciales."
    fi
    ;;
esac

exit 0
