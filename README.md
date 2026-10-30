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

Instala los scripts en `.agentflow/`, construye el grafo de código (si tienes
graphify) y escribe `.agentflow/context.md` (stacks, comandos, arquitectura y
convenciones, máximo 120 líneas).

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
- `jq`, `git`, `python3` y `gh` autenticado.
- Opcional: `graphify` (ver abajo).
- Para tickets de Jira: el MCP de Atlassian que trae el plugin (pide OAuth la primera vez).
- Escáneres: `brew install gitleaks semgrep trivy`. Si falta alguno, el flujo lo reporta como incompleto; no lo da por limpio.

## Navegación del código: token-goat y graphify (opcionales)

Los dos son opcionales y cada uno tiene un papel:

| Herramienta | Para qué la usan los agentes |
|---|---|
| [token-goat](https://github.com/DFKHelper/token-goat) | **Leer**: `symbol`, `outline`, `read archivo::Clase.metodo`, `semantic`. Devuelve el fragmento, no el archivo. |
| graphify | **Relaciones**: `affected` (impacto de un cambio) y `path` (cómo se conectan dos piezas), también entre repos. |

No se usa `token-goat impact` para impacto: en pruebas omitió llamadores y una
prueba existente que graphify sí encontró. Y ningún resultado vacío cuenta como
"no existe": los agentes lo confirman con Grep.

### graphify

Con [graphify](https://github.com/Graphify-Labs/graphify) instalado, cada repo tiene un
grafo de clases, funciones y sus relaciones, extraído del AST en local: sin LLM y
sin costo de tokens. `scout`, `planner` y `reviewer` lo usan para ver qué depende de lo que cambia.

```
uv tool install graphifyy
```

- `.agentflow/graph.sh` construye `graphify-out/graph.json` o lo pone al día; `/eng-flow`
  lo corre antes de cada tarea. Queda fuera de git (en `.git/info/exclude`).
- `/eng-context` además agrega el repo al grafo global (`~/.graphify/global-graph.json`),
  para consultar entre repos: `graphify query "…" --graph ~/.graphify/global-graph.json`.
- No hace falta `graphify install` ni `graphify claude install`: el plugin llama al CLI
  directamente. El hook de graphify interrumpiría cada `Read` y `Grep` de la sesión.
- Sin graphify todo funciona igual, con Grep y Glob.

En las pruebas, Java, TypeScript, React y Swift se extraen completos. En Kotlin y Dart
la extracción es parcial (Dart solo clases; un archivo Kotlin válido salió con aviso
de error de sintaxis), así que ahí el grafo orienta pero no reemplaza a Grep.

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
