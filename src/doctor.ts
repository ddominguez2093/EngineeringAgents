import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import type { AgentFlowConfig } from "./config.js";

/**
 * Preflight: verifica que TODO lo necesario para correr el pipeline este en su
 * lugar y dice exactamente que falta. Corre sin llamar al modelo (no gasta API).
 */

interface Check {
  name: string;
  ok: boolean;
  hint?: string;
}

function has(cmd: string): boolean {
  try {
    execSync(`command -v ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

const SCANNER_BIN: Record<string, string> = {
  semgrep: "semgrep",
  trivy: "trivy",
  gitleaks: "gitleaks",
  "npm-audit": "npm",
};

export function doctor(workspace: string, cfg: AgentFlowConfig | null): {
  checks: Check[];
  ready: boolean;
} {
  const checks: Check[] = [];

  checks.push({
    name: "ANTHROPIC_API_KEY",
    ok: !!process.env.ANTHROPIC_API_KEY,
    hint: "export ANTHROPIC_API_KEY=sk-ant-...",
  });

  checks.push({
    name: "Agent SDK instalado",
    ok: existsSync(join(workspace, "node_modules", "@anthropic-ai", "claude-agent-sdk")),
    hint: "npm install",
  });

  checks.push({
    name: ".agentflow/config.yaml",
    ok: existsSync(join(workspace, ".agentflow", "config.yaml")),
    hint: "agentflow init",
  });

  checks.push({
    name: ".mcp.json (Atlassian Rovo)",
    ok: existsSync(join(workspace, ".mcp.json")),
    hint: "necesario para que el Analyst lea Jira; autentica con: npx mcp-remote https://mcp.atlassian.com/v1/sse",
  });

  checks.push({
    name: ".claude/skills",
    ok: existsSync(join(workspace, ".claude", "skills")),
    hint: "carpeta de skills que el SDK carga (ponytail + lenguajes)",
  });

  if (cfg) {
    for (const s of cfg.security.scanners) {
      const bin = SCANNER_BIN[s] ?? s;
      checks.push({
        name: `escaner: ${s}`,
        ok: has(bin),
        hint: `el Guardian lo usa; instala '${bin}' (brew install ${bin})`,
      });
    }
    const legacy = (cfg as unknown as { migration?: { legacyPath?: string } })
      .migration?.legacyPath;
    if (legacy) {
      checks.push({
        name: `legacy/ (fuente iOS)`,
        ok: existsSync(join(workspace, legacy)),
        hint: `coloca el codigo iOS en '${legacy}' para que el Librarian genere la matriz de paridad`,
      });
    }
  }

  // Los escaneres no bloquean el arranque (el Guardian degrada); lo demas si.
  const blocking = checks.filter((c) => !c.name.startsWith("escaner"));
  const ready = blocking.every((c) => c.ok);
  return { checks, ready };
}

export function printDoctor(workspace: string, cfg: AgentFlowConfig | null): boolean {
  const { checks, ready } = doctor(workspace, cfg);
  console.log("\nagentflow doctor — preflight\n");
  for (const c of checks) {
    console.log(`  ${c.ok ? "OK " : "-- "} ${c.name}${c.ok ? "" : `  ->  ${c.hint ?? ""}`}`);
  }
  console.log(
    ready
      ? "\nTodo lo esencial esta listo. Puedes correr: agentflow scan  y luego  agentflow run <TICKET>\n"
      : "\nFaltan cosas esenciales (marcadas con --). Resuelvelas y vuelve a correr 'agentflow doctor'.\n",
  );
  return ready;
}
