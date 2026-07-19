#!/usr/bin/env node
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { stringify } from "yaml";
import { createInterface } from "node:readline/promises";
import { stdin, stdout } from "node:process";
import { DEFAULT_CONFIG, loadConfig } from "./config.js";
import { Orchestrator } from "./orchestrator.js";
import { printDoctor } from "./doctor.js";
import { runLibrarianScan } from "./librarian.js";

/**
 * CLI de agentflow. Instalable en cualquier workspace.
 *
 *   agentflow init            -> crea .agentflow/ (config semilla)
 *   agentflow doctor          -> preflight: dice que falta para poder correr
 *   agentflow scan            -> el Librarian analiza el repo (y legacy/) de verdad
 *   agentflow run <TICKET>    -> corre el pipeline para un ticket de Jira
 *   agentflow resume <TICKET> -> reanuda una corrida
 */

const [, , cmd, arg] = process.argv;
const workspace = process.cwd();

async function ask(q: string): Promise<string> {
  const rl = createInterface({ input: stdin, output: stdout });
  const a = await rl.question(q);
  rl.close();
  return a.trim();
}

async function humanGate(gate: "A" | "B", payload: unknown) {
  console.log(`\n===== GATE ${gate} — revision humana =====`);
  console.log(typeof payload === "string" ? payload : JSON.stringify(payload, null, 2));
  const answer = await ask(
    gate === "A"
      ? "\nAprobar diseno y continuar? [y = aprobar / cualquier otra cosa = feedback]: "
      : "\nPR listo. Enter para registrar (el merge lo haces tu en Git/GitHub): ",
  );
  if (gate === "B") return { approved: true };
  if (answer.toLowerCase() === "y") return { approved: true };
  return { approved: false, feedback: answer };
}

async function init() {
  const dir = join(workspace, ".agentflow");
  if (existsSync(join(dir, "config.yaml"))) {
    console.log(".agentflow ya existe. Corre 'agentflow doctor' para ver que falta.");
    return;
  }
  mkdirSync(join(dir, "context"), { recursive: true });
  mkdirSync(join(dir, "runs"), { recursive: true });
  writeFileSync(join(dir, "config.yaml"), stringify(DEFAULT_CONFIG));
  writeFileSync(
    join(dir, "context", "PROJECT_CONTEXT.md"),
    `# PROJECT_CONTEXT\n\n> Semilla. Corre 'agentflow scan' para que el Librarian lo pueble.\n`,
  );
  console.log("Inicializado .agentflow/. Ahora: edita config.yaml, corre 'agentflow doctor', luego 'agentflow scan'.");
}

async function scan() {
  const config = loadConfig(workspace);
  if (!printDoctor(workspace, config)) {
    process.exit(1);
  }
  console.log("\nLibrarian escaneando el workspace...\n");
  const summary = await runLibrarianScan(workspace, config);
  console.log(summary);
  console.log("\nListo. Revisa .agentflow/context/ (y docs/CAPABILITY_MATRIX.md si es migracion).");
}

async function run(ticket: string) {
  if (!ticket) {
    console.error("Uso: agentflow run <TICKET-ID>");
    process.exit(1);
  }
  const config = loadConfig(workspace);
  if (!printDoctor(workspace, config)) {
    console.error("Preflight incompleto. Resuelve lo marcado y reintenta.");
    process.exit(1);
  }
  const orch = new Orchestrator(ticket, { workspace, config, humanGate });
  const state = await orch.run();
  console.log(`\nPipeline terminado en etapa: ${state.stage}`);
  console.log(`Log de auditoria en .agentflow/runs/`);
}

(async () => {
  switch (cmd) {
    case "init":
      await init();
      break;
    case "doctor":
      printDoctor(workspace, existsSync(join(workspace, ".agentflow", "config.yaml")) ? loadConfig(workspace) : null);
      break;
    case "scan":
      await scan();
      break;
    case "run":
    case "resume":
      await run(arg);
      break;
    default:
      console.log(
        "agentflow — equipo de ingenieria como agentes\n\n" +
          "  agentflow init            Crea .agentflow/ (config semilla)\n" +
          "  agentflow doctor          Preflight: dice que falta para correr\n" +
          "  agentflow scan            El Librarian analiza el repo (y legacy/)\n" +
          "  agentflow run <TICKET>    Corre el pipeline para un ticket de Jira\n" +
          "  agentflow resume <TICKET> Reanuda una corrida\n",
      );
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
