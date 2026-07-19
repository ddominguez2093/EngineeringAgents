import type { HookInput, HookJSONOutput } from "@anthropic-ai/claude-agent-sdk";

/**
 * Hook PreToolUse: guardrail determinista que corre ANTES de ejecutar una tool.
 *
 * Un equipo de agentes con Bash y Write es poderoso y peligroso. Este hook bloquea
 * comandos destructivos o de exfiltracion sin depender de que el LLM "decida bien".
 * La politica la define el Guardian; el hook la aplica. Es la red de seguridad que
 * hace aceptable correr el pipeline con permisos amplios (ver README, modelo de seguridad).
 *
 * Devuelve permissionDecision:'deny' para cancelar la tool; {} para dejarla pasar.
 */

const DANGEROUS_BASH = [
  /rm\s+-rf\s+\/(?!tmp|var\/tmp)/, // rm -rf en rutas del sistema
  /\bcurl\b[^|]*\|\s*(sh|bash)/, // curl | sh
  /\bwget\b[^|]*\|\s*(sh|bash)/,
  /git\s+push\s+.*--force.*\b(main|master)\b/, // force push a main
  /git\s+push\s+.*\b(main|master)\b.*--force/,
  /\b(chmod|chown)\s+-R\s+777/,
  /:\(\)\s*\{.*\}\s*;/, // fork bomb
];

const SECRET_PATHS = [
  /\.env(\.|$)/,
  /id_rsa/,
  /\.pem$/,
  /credentials/i,
  /\.aws\//,
  /\.ssh\//,
];

function deny(reason: string): HookJSONOutput {
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  };
}

/** Pura y testeable: recibe el input del hook, devuelve la decision. */
export async function securityPreToolUse(
  input: HookInput,
): Promise<HookJSONOutput> {
  if (input.hook_event_name !== "PreToolUse") return {};
  const toolName = input.tool_name;
  const toolInput = (input.tool_input ?? {}) as Record<string, unknown>;

  if (toolName === "Bash") {
    const cmd = String(toolInput.command ?? "");
    for (const pattern of DANGEROUS_BASH) {
      if (pattern.test(cmd)) {
        return deny(
          `Comando bloqueado por politica de seguridad (patron: ${pattern}). Requiere aprobacion humana explicita.`,
        );
      }
    }
  }

  if (toolName === "Write" || toolName === "Edit" || toolName === "Read") {
    const path = String(toolInput.file_path ?? toolInput.path ?? "");
    for (const pattern of SECRET_PATHS) {
      if (pattern.test(path)) {
        return deny(
          `Acceso a un archivo de secretos bloqueado (${path}). Los agentes no leen ni escriben credenciales.`,
        );
      }
    }
  }

  return {};
}
