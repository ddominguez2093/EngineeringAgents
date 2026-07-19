import { query, type Options } from "@anthropic-ai/claude-agent-sdk";
import { buildAgents } from "./agents.js";
import { securityPreToolUse } from "./hooks/security-hooks.js";
import type { AgentFlowConfig } from "./config.js";
import type { RiskLevel } from "./types.js";

/**
 * Construccion centralizada de las Options del SDK, para que TODOS los agentes
 * corran con el mismo cableado: agentes, skills, MCP (via settingSources),
 * hooks de seguridad y modo de permisos.
 */
export function buildOptions(
  workspace: string,
  cfg: AgentFlowConfig,
  risk: RiskLevel,
): Options {
  const agents = buildAgents(cfg, { risk });
  const skills = Array.from(
    new Set(["ponytail", "ui-ux-pro-max", ...cfg.stacks]),
  );

  return {
    cwd: workspace,
    agents: agents as Options["agents"],
    // Auto-aprueba la invocacion de subagentes.
    allowedTools: ["Agent", "Read", "Grep", "Glob"],
    // Carga .claude/skills, .claude/agents, CLAUDE.md y .mcp.json del proyecto.
    settingSources: ["project"],
    skills,
    permissionMode: cfg.runtime.permissionMode,
    hooks: {
      PreToolUse: [{ hooks: [securityPreToolUse] }],
    },
  };
}

/** Corre un agente por nombre y devuelve su mensaje final (el artefacto) + session_id. */
export async function runAgent(args: {
  agentName: string;
  prompt: string;
  workspace: string;
  cfg: AgentFlowConfig;
  risk: RiskLevel;
  resume?: string;
}): Promise<{ result: string; sessionId?: string }> {
  const options = buildOptions(args.workspace, args.cfg, args.risk);
  if (args.resume) options.resume = args.resume;

  let result = "";
  let sessionId: string | undefined;
  for await (const message of query({
    prompt: `Use the ${args.agentName} agent. ${args.prompt}`,
    options,
  })) {
    if ("session_id" in message && message.session_id) {
      sessionId = message.session_id;
    }
    if (message.type === "result" && "result" in message) {
      result = (message as { result: string }).result;
    }
  }
  return { result, sessionId };
}
