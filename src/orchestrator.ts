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
      `Con este RefinedTicket, propon TechDesign + Subtasks en YAML.\n\n${refined}`,
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
        `Implementa la subtask respetando el diseno.\n\n${design}\n\nFeedback previo de pruebas (si hay):\n${testReport}`,
        this.state.risk,
      );
      this.audit(`03-code-change-${this.state.loopCounters["redGreen"] ?? 0}.txt`, diff);

      testReport = await this.run1(
        "tester",
        `Escribe y CORRE pruebas para este diff. Devuelve TestReport en YAML.\n\n${diff}`,
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
        `Revisa este cambio contra el diseno. Si apruebas, crea el draft PR. Devuelve ReviewVerdict.\n\nDISENO:\n${design}\n\nDIFF:\n${diff}\n\nPRUEBAS:\n${testReport}`,
        this.state.risk,
      );
      this.audit(`05-review-verdict-${this.state.loopCounters["review"] ?? 0}.yaml`, review);
      if (/verdict:\s*approved/i.test(review)) break;
      diff = await this.run1(
        "coder",
        `El reviewer pidio cambios. Aplicalos.\n\n${review}`,
        this.state.risk,
      );
    } while (this.budget("review", cfg.loopBudgets.review));

    // 6) LOOP DE REMEDIACION: Guardian -> Coder
    this.state.stage = "guardian";
    let security = "";
    do {
      security = await this.run1(
        "guardian",
        `Analiza seguridad del PR. Corre los escaneres (${cfg.security.scanners.join(", ")}) y devuelve SecurityVerdict.\n\nDIFF:\n${diff}`,
        this.state.risk,
      );
      this.audit(`06-security-verdict-${this.state.loopCounters["remediation"] ?? 0}.yaml`, security);
      if (/verdict:\s*pass/i.test(security)) break;
      diff = await this.run1(
        "coder",
        `El Guardian encontro vulnerabilidades. Remediar sin romper las pruebas.\n\n${security}`,
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
