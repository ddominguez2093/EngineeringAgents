# EngineeringAgenticFlow

Un **equipo de ingeniería completo, como agentes especializados** sobre el
[Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview). Lleva un
ticket de Jira desde el refinamiento hasta un Pull Request probado y seguro — con
el **merge final siempre humano**.

```
Jira → Analyst → Architect → ⟦Gate A⟧ → (Coder ⇄ Tester) → Reviewer → Guardian → ⟦Gate B: merge humano⟧
                                             ↑ Librarian da contexto a todos ↑
```

Lee el diseño completo en [`docs/AGENT_STRATEGY.md`](docs/AGENT_STRATEGY.md) y el
diagrama en [`docs/FLOW.mermaid`](docs/FLOW.mermaid).

## Los agentes

| Agente | Rol | Modelo | Escribe código |
|---|---|---|:--:|
| **Analyst** | Refina el ticket de Jira (Rovo), encuentra gaps, escala dudas de negocio | Opus | no |
| **Architect** | Propone la solución (ADR) + subtasks + clasifica riesgo | Opus | no |
| **Librarian** | Mantiene el "cerebro del proyecto" (arquitectura, patrones, UI/UX) | Sonnet | no |
| **Coder** | Implementa con filosofía *ponytail* (mínimo código, reuso) | Sonnet/Opus | **sí** |
| **Dev Tester** | Escribe y **corre** las pruebas; loop rojo-verde con el Coder | Sonnet | tests |
| **Architect Reviewer** | Revisa contra el diseño; crea el draft PR | Opus | no |
| **Guardian** | Seguridad: Semgrep/Trivy/gitleaks **+** razonamiento OWASP | Opus | no |

## Ideas clave

- **Contratos entre etapas**: cada agente produce un artefacto con esquema fijo (`src/types.ts`), no texto libre.
- **Verificación con herramientas reales**: el Tester corre las pruebas; el Guardian corre escáneres. El LLM interpreta; las herramientas dictaminan.
- **Loops acotados**: rojo-verde (≤3), review (≤2), remediación (≤2). Al agotarse, escalan a humano. Seguridad nunca se aprueba por agotamiento.
- **Dos gates humanos**: aprobación de diseño (Gate A, saltable si low-risk) y merge (Gate B, siempre).
- **Ruteo por riesgo**: el Architect etiqueta low/medium/high; high-risk usa modelos más fuertes y Guardian estricto.
- **Mínimo privilegio + hooks**: solo el Coder escribe; `PreToolUse` bloquea comandos peligrosos y acceso a secretos (`src/hooks/security-hooks.ts`).
- **Portátil**: todo vive en `.agentflow/` dentro del repo.

## Uso

```bash
npm install                          # repone dependencias (incl. Agent SDK)
export ANTHROPIC_API_KEY=sk-ant-...
npx tsx src/index.ts init            # crea .agentflow/
npx tsx src/index.ts doctor          # preflight: dice que falta
npx tsx src/index.ts scan            # el Librarian analiza el repo (y legacy/)
npx tsx src/index.ts run PROJ-123    # corre el pipeline para un ticket de Jira
```

Runbook detallado (Jira/Rovo, escáneres, migración): [`docs/RUNBOOK.md`](docs/RUNBOOK.md).
Instalar en otro repo: `./scripts/install.sh /ruta/a/mi/repo`.

## Modelo de seguridad del propio sistema

El pipeline corre en `permissionMode: bypassPermissions` (autónomo, sin prompts).
Lo que lo hace seguro NO es pedir permiso, sino dos guardrails deterministas:

1. **Tools mínimas por agente** (`src/agents.ts`): solo el Coder escribe; Analyst y
   reviewers son read-only; el Guardian corre escáneres pero no edita.
2. **Hook `PreToolUse`** (`src/hooks/security-hooks.ts`): bloquea comandos
   destructivos (`rm -rf /`, `curl | sh`, force-push a main) y el acceso a secretos
   (`.env`, llaves, credenciales) ANTES de ejecutarse.

Cambia `runtime.permissionMode` a `"default"` en `.agentflow/config.yaml` si prefieres
aprobar cada tool a mano.

## Skills

Viven en `.claude/skills/` para que el SDK los descubra (`settingSources:['project']`)
y se atan a cada agente:

- **ponytail** — minimalismo/reuso (Coder + Architect Reviewer).
- **ui-ux-pro-max** — inteligencia de diseño UI/UX vendorizada (67 estilos, 161
  paletas, 57 pares tipográficos, 22 stacks incl. Flutter/SwiftUI/React Native),
  con base de datos consultable por `scripts/search.py`. Atada a Coder, Architect
  y Architect Reviewer (sistema de diseño + adaptive por plataforma).
- **Packs por lenguaje** — java, csharp, kotlin-android, swift-ios, flutter-dart,
  react-native. Se atan al Coder/Tester según el stack de `.agentflow/config.yaml`.

Agregar un lenguaje o skill = agregar una carpeta en `.claude/skills/`. Sin tocar el orquestador.

## Seguridad y CI

- **Guardian** corre Semgrep con `p/owasp-top-ten` + `p/secrets` + reglas custom
  Dart/Flutter en `.agentflow/security/semgrep-flutter.yml` (http sin TLS, secretos
  hardcodeados, `Random()` inseguro, SQL interpolado, WebView JS, cert pinning
  deshabilitado, secure-storage en web), más Trivy y gitleaks.
- **CI multiplataforma** (`.github/workflows/flutter-multiplatform.yml`): analyze +
  test (con golden tests de paridad), Guardian (SAST), y build de humo en las 4
  plataformas. Un cambio no está verde hasta que compila en iOS/Android/macOS/Web.

## Estado

Orquestación **cableada contra el Agent SDK real (v0.3.x)**: agentes, skills, MCP de
Jira (`.mcp.json`), hooks de seguridad (forma correcta `PreToolUse`), gates, loops,
contratos, `resume`, y comandos `doctor`/`scan`. Typecheck limpio contra los tipos
del SDK; `doctor` probado.

Para correrlo solo faltan cosas de TU entorno (no de código), y `agentflow doctor`
te las lista: `npm install`, `ANTHROPIC_API_KEY`, OAuth del MCP de Atlassian, y los
escáneres (semgrep/trivy/gitleaks) en el PATH. Ver [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

Cableado completo y verificado: typecheck contra el SDK real, `doctor` probado,
las 7 reglas Semgrep validadas ejecutándose (3 hallazgos en el fixture de prueba),
y el skill `ui-ux-pro-max` vendorizado con su base de datos consultable funcionando.
