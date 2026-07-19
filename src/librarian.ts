import { join } from "node:path";
import { existsSync } from "node:fs";
import { runAgent } from "./sdk.js";
import type { AgentFlowConfig } from "./config.js";

/**
 * Librarian real: invoca al agente para escanear el workspace (y `legacy/` si es
 * una migracion) y escribir el "cerebro del proyecto".
 *
 * A diferencia del scaffold de `init` (que solo deja la config semilla), esto SI
 * llama al modelo y produce PROJECT_CONTEXT.md, sub-docs y, en migracion, la
 * matriz de capacidades.
 */
export async function runLibrarianScan(
  workspace: string,
  cfg: AgentFlowConfig,
): Promise<string> {
  const legacy = (cfg as unknown as { migration?: { legacyPath?: string } })
    .migration?.legacyPath;
  const hasLegacy = legacy ? existsSync(join(workspace, legacy)) : false;

  const migrationBlock = hasLegacy
    ? `\n\nEsto es una MIGRACION. El codigo fuente (iOS/VIPER) esta en '${legacy}' (read-only, spec de paridad).
Ademas de lo anterior, produce docs/CAPABILITY_MATRIX.md: por cada dependencia nativa
o de terceros de cada modulo, mapea a un plugin Flutter y su soporte por plataforma
(iOS/Android/macOS/Web), marcando gaps (sobre todo en Web). Extrae de cada Interactor/
Presenter la logica como spec de paridad para el Analyst.`
    : "";

  const prompt = `Escanea este workspace y escribe/actualiza en .agentflow/context/:
- architecture.md, conventions.md, ui-ux.md, glossary.md
- PROJECT_CONTEXT.md (indice maestro que resume todo).
Detecta el stack y los comandos reales de build/test/lint.${migrationBlock}

Se conciso y factual. Escribe los archivos con la tool Write.`;

  const { result } = await runAgent({
    agentName: "librarian",
    prompt,
    workspace,
    cfg,
    risk: "low",
  });
  return result;
}
