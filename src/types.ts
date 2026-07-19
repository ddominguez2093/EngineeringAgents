/**
 * Contratos entre etapas del pipeline.
 *
 * Principio de diseño: los agentes NO se pasan texto libre. Cada etapa produce
 * un artefacto con esquema fijo que la siguiente consume. Esto hace cada handoff
 * inspeccionable y bloqueable (Definition of Ready / Definition of Done).
 */

export type RiskLevel = "low" | "medium" | "high";

/** Salida del Analyst. */
export interface RefinedTicket {
  ticketId: string;
  title: string;
  context: string;
  /** Criterios de aceptacion en formato Given/When/Then. */
  acceptanceCriteria: string[];
  /** Reglas de negocio hechas explicitas. */
  businessRules: string[];
  dependencies: string[];
  /** Preguntas que BLOQUEAN: si hay alguna, el pipeline se detiene y escala al humano. */
  openQuestions: string[];
  preliminaryRisk: RiskLevel;
  /** El Analyst confirma que el ticket esta listo para el Architect. */
  definitionOfReady: boolean;
}

/** Salida del Architect. */
export interface TechDesign {
  ticketId: string;
  /** ADR: decision + alternativas descartadas con su razon. */
  decision: string;
  discardedAlternatives: { option: string; reason: string }[];
  affectedComponents: string[];
  /** Contratos/interfaces nuevas o modificadas. */
  interfaces: string[];
  expectedTestPlan: string[];
  /** Riesgo final: decide cuantos gates aplican (ver §6 de la estrategia). */
  risk: RiskLevel;
}

export interface Subtask {
  id: string;
  description: string;
  acceptanceCriteria: string[];
  /** Subtasks high-risk escalan el Coder a un modelo mas capaz. */
  risk: RiskLevel;
}

/** Salida del Coder. */
export interface CodeChange {
  ticketId: string;
  subtaskId: string;
  branch: string;
  filesTouched: string[];
  /** Decisiones y, sobre todo, que se dejo fuera a proposito (filosofia ponytail). */
  changelog: string;
}

/** Salida del Tester. */
export interface TestReport {
  ticketId: string;
  testsAdded: string[];
  /** Resultado de CORRER las pruebas de verdad, no de suponer. */
  run: { passed: boolean; output: string };
  coveragePct: number | null;
  missingEdgeCases: string[];
}

/** Salida del Architect Reviewer. */
export interface ReviewVerdict {
  ticketId: string;
  verdict: "approved" | "changes_requested";
  findings: { severity: "info" | "minor" | "major"; note: string }[];
  draftPrUrl?: string;
}

/** Salida del Guardian. */
export interface SecurityVerdict {
  ticketId: string;
  verdict: "pass" | "fail";
  findings: {
    severity: "low" | "medium" | "high" | "critical";
    owaspCategory?: string;
    evidence: string; // output real de Semgrep/Trivy/gitleaks
    note: string;
  }[];
}

/** Estado que el Orchestrator persiste para poder reanudar (`resume`). */
export interface RunState {
  ticketId: string;
  stage:
    | "analyze"
    | "design"
    | "gate_a"
    | "implement"
    | "review"
    | "guardian"
    | "gate_b"
    | "done";
  risk: RiskLevel;
  /** session_id del SDK para reanudar la conversacion. */
  sessionId?: string;
  loopCounters: Record<string, number>;
  startedAt: string;
}
