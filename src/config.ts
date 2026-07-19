import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { parse } from "yaml";
import type { RiskLevel } from "./types.js";

/**
 * Configuracion del workspace. Vive en `.agentflow/config.yaml` dentro del repo,
 * asi que el equipo de agentes es portatil: clonas el repo y ya conoce tu stack.
 */
export interface AgentFlowConfig {
  /** Stacks detectados por el Librarian; deciden que skill packs se atan. */
  stacks: string[]; // p.ej. ["java", "flutter-dart"]
  models: {
    analyst: string;
    architect: string;
    librarian: string;
    coder: string;
    coderHighRisk: string;
    tester: string;
    reviewer: string;
    guardian: string;
  };
  /** Presupuesto de iteraciones por loop (ver §5 de la estrategia). */
  loopBudgets: {
    redGreen: number; // Coder <-> Tester
    review: number; // Reviewer -> Coder
    remediation: number; // Guardian -> Coder
  };
  /** En que niveles de riesgo el Gate A (aprobacion humana de diseno) es obligatorio. */
  gateARequiredFor: RiskLevel[];
  /** Comandos del proyecto que el Tester/Guardian ejecutan de verdad. */
  commands: {
    test: string;
    lint: string;
    build: string;
  };
  security: {
    /** Herramientas deterministas que corre el Guardian. */
    scanners: string[]; // p.ej. ["semgrep", "trivy", "gitleaks", "npm-audit"]
    /** Severidad minima que BLOQUEA el PR. */
    blockingSeverity: "medium" | "high" | "critical";
  };
  runtime: {
    /**
     * Modo de permisos del SDK. En un pipeline autonomo headless se usa
     * "bypassPermissions": los guardrails los dan los hooks PreToolUse + las
     * tools minimas por agente, no prompts interactivos. Usa "default" si
     * quieres aprobar cada tool a mano.
     */
    permissionMode: "default" | "acceptEdits" | "bypassPermissions";
  };
}

export const DEFAULT_CONFIG: AgentFlowConfig = {
  stacks: [],
  models: {
    analyst: "opus",
    architect: "opus",
    librarian: "sonnet",
    coder: "sonnet",
    coderHighRisk: "opus",
    tester: "sonnet",
    reviewer: "opus",
    guardian: "opus",
  },
  loopBudgets: { redGreen: 3, review: 2, remediation: 2 },
  gateARequiredFor: ["medium", "high"],
  commands: { test: "", lint: "", build: "" },
  security: {
    scanners: ["semgrep", "trivy", "gitleaks", "npm-audit"],
    blockingSeverity: "high",
  },
  runtime: {
    permissionMode: "bypassPermissions",
  },
};

export function loadConfig(workspace: string): AgentFlowConfig {
  const path = join(workspace, ".agentflow", "config.yaml");
  if (!existsSync(path)) {
    throw new Error(
      `No se encontro ${path}. Corre "agentflow init" primero para que el Librarian analice el workspace.`,
    );
  }
  const parsed = parse(readFileSync(path, "utf8")) as Partial<AgentFlowConfig>;
  return { ...DEFAULT_CONFIG, ...parsed };
}
