# Engineering Agentic Flow

Plugin de Claude Code que lleva un ticket de Jira, o una tarea descrita, hasta un PR
en borrador. Elige cuánto proceso y qué modelo usar según el riesgo del cambio.

Stacks: **React web · Flutter · iOS (Swift) · Android (Kotlin + Compose) · Spring Boot (Java)**.

## Instalación

```
/plugin marketplace add ddominguez2093/EngineeringAgents
/plugin install engineering-agentic-flow@bitstream-agents
```

En cada repo donde lo uses, una sola vez:

```
/eng-context
```

Instala `.agentflow/verify.sh` y `.agentflow/scan.sh` y escribe `.agentflow/context.md`
(stacks, comandos, arquitectura y convenciones, máximo 120 líneas).

## Uso

```
/eng-flow PROJ-123
/eng-flow corregir el salto de línea en el título de la tarjeta de pedido
/eng-flow --profundo PROJ-456
```

## Tres carriles

| Carril | Para qué | Qué corre |
|---|---|---|
| **rápido** | Cambio localizado y evidente | La sesión principal hace el cambio y corre la verificación. Sin subagentes. |
| **estándar** | Una feature o un bug normal | Plan → implementación con pruebas por subtask → verificación → revisión → escáneres. |
| **profundo** | Auth, pagos, datos personales, migraciones, APIs públicas, varios stacks | Lo anterior con aprobación tuya del diseño y revisión de seguridad dedicada. |

El carril se elige solo; puedes forzarlo con `--rapido`, `--estandar` o `--profundo`.
El merge siempre lo hace una persona.

## Qué modelo hace qué

| Agente | Trabajo | Modelo | En carril profundo |
|---|---|---|---|
| `scout` | Ubicar código, inventariar un repo | haiku | haiku |
| `verifier` | Correr lint, pruebas, build y escáneres; resumir fallos | haiku | haiku |
| `planner` | Huecos de negocio, riesgo, subtasks | sonnet | **opus** |
| `coder` | Implementar una subtask con sus pruebas | sonnet (opus si es `difícil`) | igual |
| `reviewer` | Revisión independiente del diff | sonnet | **opus** |
| `guardian` | Seguridad lógica | no corre | **opus** |

La sesión principal orquesta: corre `/eng-flow` con sonnet (`/model sonnet`). Opus en
la sesión principal no mejora el resultado y encarece cada etapa.

## Requisitos
- `jq`, `git` y `gh` autenticado.
- Para tickets de Jira: el MCP de Atlassian que trae el plugin (pide OAuth la primera vez).
- Escáneres: `brew install gitleaks semgrep trivy`. Si falta alguno, el flujo lo reporta como incompleto; no lo da por limpio.

## Ajustar la verificación
`verify.sh` detecta el proyecto de los archivos tocados y corre sus comandos. Cuando
no acierta (iOS siempre necesita esquema y destino), define los pasos en
`.agentflow/verify.conf`:

```
# directorio :: comando
ios :: xcodebuild test -scheme MiApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
web :: pnpm run typecheck
```

Revisa qué correría con `.agentflow/verify.sh --list --all`.

## Más
- Diseño y motivos: [`docs/AGENT_STRATEGY.md`](docs/AGENT_STRATEGY.md)
- Diagrama: [`docs/FLOW.mermaid`](docs/FLOW.mermaid)
