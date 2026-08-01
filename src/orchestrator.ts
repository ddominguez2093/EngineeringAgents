import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { runAgent } from "./sdk.js";
import type { AgentFlowConfig } from "./config.js";
import type { RiskLevel, RunState } from "./types.js";

/**
 * Orchestrator: el "director" del pipeline. No razona; ejecuta.
 *
 * Conduce Analyst -> Architect -> [Gate A] -> (Coder <-> Tester) -> Reviewer ->
 * Guardian -> [Gate B], aplica los presupuestos de loop, escribe el log de
 * auditoria y persiste el estado para reanudar.
 */

export interface OrchestratorDeps {
  workspace: string;
  config: AgentFlowConfig;
  /** Callback de gate humano: retorna true para continuar, false/patch para corregir. */
  humanGate: (
    gate: "A" | "B",
    payload: unknown,
  ) => Promise<{ approved: boolean; feedback?: string }>;
}

export class Orchestrator {
  private state: RunState;
  private runDir: string;

  constructor(
    private ticketId: string,
    private deps: OrchestratorDeps,
  ) {
    this.state = {
      ticketId,
      stage: "analyze",
      risk: "medium",
      loopCounters: {},
      startedAt: new Date().toISOString(),
    };
    this.runDir = join(
      deps.workspace,
      ".agentflow",
      "runs",
      `${ticketId}-${Date.now()}`,
    );
    mkdirSync(this.runDir, { recursive: true });
  }

  private audit(name: string, content: unknown): void {
    const body =
      typeof content === "string" ? content : JSON.stringify(content, null, 2);
    writeFileSync(join(this.runDir, name), body);
  }

  private budget(loop: string, max: number): boolean {
    const n = this.state.loopCounters[loop] ?? 0;
    this.state.loopCounters[loop] = n + 1;
    return n < max;
  }

  private async run1(agentName: string, prompt: string, risk: RiskLevel): Promise<string> {
    const { result, sessionId } = await runAgent({
      agentName,
      prompt,
      workspace: this.deps.workspace,
      cfg: this.deps.config,
      risk,
      resume: this.state.sessionId,
    });
    if (sessionId) this.state.sessionId = sessionId;
    return result;
  }

  /** Ejecuta el pipeline completo para el ticket. */
  async run(): Promise<RunState> {
    const cfg = this.deps.config;

    // 1) ANALYST
    this.state.stage = "analyze";
    const refined = await this.run1(
      "analyst",
      `Refina el ticket ${this.ticketId} de Jira. Devuelve RefinedTicket en YAML.`,
      "medium",
    );
    this.audit("01-refined-ticket.yaml", refined);
    if (/definitionOfReady:\s*false/i.test(refined)) {
      this.audit("STOPPED.txt", "Detenido: openQuestions bloqueantes. El Analyst comento Jira; espera respuesta humana.");
      return this.state;
    }

    // 2) ARCHITECT
    this.state.stage = "design";
    const design = await this.run1(
      "architect",
      `Con este RefinedTicket, propon TechDesign + Subtasks en YAML.\n\n${clip(refined)}`,
      "medium",
    );
    this.audit("02-tech-design.yaml", design);
    this.state.risk = extractRisk(design);

    // 3) GATE A — aprobacion humana de diseno (si el riesgo lo exige)
    if (cfg.gateARequiredFor.includes(this.state.risk)) {
      this.state.stage = "gate_a";
      const gate = await this.deps.humanGate("A", design);
      if (!gate.approved) {
        this.audit("GATE_A_REJECTED.txt", gate.feedback ?? "");
        return this.state;
      }
    }

    // 4) LOOP ROJO-VERDE: Coder <-> Tester
    this.state.stage = "implement";
    let diff = "";
    let testReport = "";
    do {
      diff = await this.run1(
        "coder",
        `Implementa la subtask respetando el diseno. Al terminar devuelve SOLO un CodeChange breve (rama, archivos tocados, changelog corto) — NO pegues el diff completo, ya vive en git.\n\n${clip(design)}\n\nFeedback previo de pruebas (si hay):\n${clip(testReport, 3000)}`,
        this.state.risk,
      );
      this.audit(`03-code-change-${this.state.loopCounters["redGreen"] ?? 0}.txt`, diff);

      testReport = await this.run1(
        "tester",
        `Escribe y CORRE pruebas para el cambio en la rama actual. Lee el diff tu mismo con git diff (no se te pega aqui). Resumen del cambio:\n${clip(diff, 3000)}\n\nDevuelve TestReport en YAML, con el output de la corrida RESUMIDO (fallos completos, exitos en una linea).`,
        this.state.risk,
      );
      this.audit(`04-test-report-${this.state.loopCounters["redGreen"] ?? 0}.yaml`, testReport);
    } while (
      /passed:\s*false/i.test(testReport) &&
      this.budget("redGreen", cfg.loopBudgets.redGreen)
    );

    if (/passed:\s*false/i.test(testReport)) {
      this.audit("ESCALATE_TESTS.txt", "Loop rojo-verde agotado sin converger. Probable hueco de diseno. Escala a humano/Architect.");
      return this.state;
    }

    // 5) LOOP DE REVIEW: Architect Reviewer -> Coder
    this.state.stage = "review";
    let review = "";
    do {
      review = await this.run1(
        "architect-reviewer",
        `Revisa el cambio de la rama actual contra el diseno: corre git diff tu mismo (no se te pega el diff). Si apruebas, crea el draft PR. Devuelve ReviewVerdict conciso.\n\nDISENO:\n${clip(design)}\n\nRESUMEN DEL CAMBIO:\n${clip(diff, 3000)}\n\nPRUEBAS:\n${clip(testReport, 3000)}`,
        this.state.risk,
      );
      this.audit(`05-review-verdict-${this.state.loopCounters["review"] ?? 0}.yaml`, review);
      if (/verdict:\s*approved/i.test(review)) break;
      diff = await this.run1(
        "coder",
        `El reviewer pidio cambios. Aplicalos y devuelve un changelog breve.\n\n${clip(review, 4000)}`,
        this.state.risk,
      );
    } while (this.budget("review", cfg.loopBudgets.review));

    // 6) LOOP DE REMEDIACION: Guardian -> Coder
    this.state.stage = "guardian";
    let security = "";
    do {
      security = await this.run1(
        "guardian",
        `Analiza seguridad del PR de la rama actual. Corre los escaneres (${cfg.security.scanners.join(", ")}) sobre el arbol de trabajo y revisa git diff tu mismo (no se te pega). Devuelve SecurityVerdict con evidencia RESUMIDA (solo hallazgos, no el output completo de las herramientas limpias).\n\nRESUMEN DEL CAMBIO:\n${clip(diff, 3000)}`,
        this.state.risk,
      );
      this.audit(`06-security-verdict-${this.state.loopCounters["remediation"] ?? 0}.yaml`, security);
      if (/verdict:\s*pass/i.test(security)) break;
      diff = await this.run1(
        "coder",
        `El Guardian encontro vulnerabilidades. Remediar sin romper las pruebas; devuelve changelog breve.\n\n${clip(security, 4000)}`,
        this.state.risk,
      );
    } while (this.budget("remediation", cfg.loopBudgets.remediation));

    if (!/verdict:\s*pass/i.test(security)) {
      // NUNCA se aprueba seguridad por agotamiento del loop.
      this.audit("SECURITY_BLOCK.txt", "Guardian sigue en fail tras las iteraciones. PR bloqueado. Escala a humano.");
      return this.state;
    }

    // 7) GATE B — merge humano (siempre)
    this.state.stage = "gate_b";
    await this.deps.humanGate("B", { review, security, diff });
    this.state.stage = "done";
    this.audit("DONE.txt", "PR listo para merge humano.");
    return this.state;
  }
}

function extractRisk(design: string): RiskLevel {
  const m = design.match(/risk:\s*(low|medium|high)/i);
  return (m?.[1]?.toLowerCase() as RiskLevel) ?? "medium";
}

/**
 * Recorta un artefacto antes de embeberlo en un prompt. Los artefactos completos
 * viven en .agentflow/runs/ (auditoria); a los prompts solo va lo esencial.
 * Sin esto, cada iteracion de loop re-paga el artefacto entero.
 */
function clip(text: string, maxChars = 6000): string {
  if (text.length <= maxChars) return text;
  return (
    text.slice(0, maxChars) +
    `\n\n[...recortado por presupuesto de tokens: ${text.length - maxChars} chars mas en .agentflow/runs/]`
  );
}
