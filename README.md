# Engineering Agentic Flow

Plugin de Claude Code que lleva un ticket de Jira, o una tarea descrita, hasta un PR
en borrador. Elige cuánto proceso y qué modelo usar según el riesgo del cambio.

Stacks: **React web · Flutter · iOS (Swift) · Android (Kotlin + Compose) · Spring Boot (Java)**.

## Instalación

Primero graphify, que es obligatorio:

```
uv tool install graphifyy
```

Luego el plugin:

```
/plugin marketplace add ddominguez2093/EngineeringAgents
/plugin install engineering-agentic-flow@bitstream-agents
```

### Actualizar
Cada versión cambia `version` en `plugin.json`; sin ese cambio, Claude Code no baja
los commits nuevos.

```
claude plugin marketplace update bitstream-agents
claude plugin update engineering-agentic-flow@bitstream-agents
```

Luego abre una sesión nueva o corre `/reload-plugins`. Revisa la versión con `claude plugin list`.

Para probar una rama sin publicarla, agrega tu copia local como marketplace (se lee
en sitio; cada cambio aplica con `/reload-plugins`):

```
claude plugin marketplace remove bitstream-agents
git clone -b <rama> https://github.com/ddominguez2093/EngineeringAgents ~/dev/EngineeringAgents
claude plugin marketplace add ~/dev/EngineeringAgents
claude plugin install engineering-agentic-flow@bitstream-agents
```

En cada repo donde lo uses, una sola vez:

```
/eng-context
```

Instala los scripts en `.agentflow/`, construye el grafo de código, lo abre en el
navegador y escribe `.agentflow/context.md` (stacks, comandos, arquitectura y
convenciones, máximo 120 líneas).

## Uso

```
/eng-flow PROJ-123
/eng-flow corregir el salto de línea en el título de la tarjeta de pedido
/eng-flow --profundo PROJ-456
/eng-graph        # actualiza el grafo y lo abre en el navegador
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
- `graphify` (obligatorio, ver abajo). Opcional: `token-goat`.
- Para tickets de Jira: el MCP de Atlassian que trae el plugin (pide OAuth la primera vez).
- Escáneres: `brew install gitleaks semgrep trivy`. Si falta alguno, el flujo lo reporta como incompleto; no lo da por limpio.

## Navegación del código: graphify y token-goat

graphify es obligatorio; token-goat, opcional. Cada uno tiene un papel:

| Herramienta | Para qué la usan los agentes |
|---|---|
| [token-goat](https://github.com/DFKHelper/token-goat) | **Leer**: `symbol`, `outline`, `read archivo::Clase.metodo`, `semantic`. Devuelve el fragmento, no el archivo. |
| graphify | **Relaciones**: `affected` (impacto de un cambio) y `path` (cómo se conectan dos piezas), también entre repos. |

No se usa `token-goat impact` para impacto: en pruebas omitió llamadores y una
prueba existente que graphify sí encontró. Y ningún resultado vacío cuenta como
"no existe": los agentes lo confirman con Grep.

### graphify (obligatorio)

Con [graphify](https://github.com/Graphify-Labs/graphify), cada repo tiene un
grafo de clases, funciones y sus relaciones, extraído del AST en local: sin LLM y
sin costo de tokens. `scout`, `planner` y `reviewer` lo usan para ver qué depende de lo que cambia.

- `.agentflow/graph.sh` construye `graphify-out/graph.json` o lo pone al día; `/eng-flow`
  lo corre antes de cada tarea en todos los carriles. Si graphify no está instalado o
  falla, el flujo se detiene. Queda fuera de git (en `.git/info/exclude`).
- **Ver el grafo:** `/eng-graph` (o `.agentflow/graph.sh --html`) genera y abre
  `graphify-out/graph.html`, una red interactiva por comunidades con búsqueda de
  nodos, y `graphify-out/GRAPH_TREE.html`, un árbol por carpetas. Necesitan internet
  para cargar sus librerías de dibujo.
- `/eng-context` además agrega el repo al grafo global (`~/.graphify/global-graph.json`),
  para consultar entre repos: `graphify query "…" --graph ~/.graphify/global-graph.json`.
- No hace falta `graphify install` ni `graphify claude install`: el plugin llama al CLI
  directamente. El hook de graphify interrumpiría cada `Read` y `Grep` de la sesión.

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
