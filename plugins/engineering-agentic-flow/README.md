# Engineering Agentic Flow — plugin de Claude Code

Un equipo de ingeniería como **subagentes de Claude Code**, usable en VSCode (o en
la CLI). Lleva un ticket de Jira desde el refinamiento hasta un PR probado y seguro,
con el **merge final siempre humano**.

## Qué incluye

**7 subagentes** (`agents/`): `analyst`, `architect`, `librarian`, `coder`,
`dev-tester`, `architect-reviewer`, `guardian`.

**Comandos** (`commands/`):
- `/eng-flow <TICKET>` — corre el flujo completo con gates humanos.
- `/eng-context` — el Librarian construye el cerebro del proyecto (y la matriz de
  capacidades en migraciones).

**Skills** (`skills/`): `ponytail` (minimalismo), `ui-ux-pro-max` (inteligencia de
diseño UI/UX con base de datos consultable), y packs por lenguaje (`java`, `csharp`,
`kotlin-android`, `swift-ios`, `flutter-dart`, `react-native`).

**Hooks** (`hooks/`): guardrail `PreToolUse` que bloquea comandos destructivos y el
acceso a secretos.

## Instalación (Claude Code en VSCode)

Desde la extensión de Claude Code en VSCode (o `claude` en la terminal integrada),
con el repo publicado en GitHub:

```
/plugin marketplace add ddominguez2093/EngineeringAgents
/plugin install engineering-agentic-flow@bitstream-agents
/reload-plugins
```

Para desarrollarlo localmente sin publicar, desde la carpeta que contiene el repo:

```
/plugin marketplace add ./EngineeringAgents
/plugin install engineering-agentic-flow@bitstream-agents
/reload-plugins
```

## Uso

```
/eng-context                 # una vez por repo: construye el contexto del proyecto
/eng-flow PROJ-123           # corre el pipeline para un ticket
```

Los subagentes también se invocan solos cuando la tarea coincide con su
`description`, o explícitamente: "usa el subagente guardian para revisar este PR".

## Requisitos

- **MCP de Atlassian/Rovo** conectado para que el `analyst`/`architect` lean/escriban
  Jira (`/mcp` en Claude Code, o el `.mcp.json` que trae el plugin).
- **gh** autenticado para que el `architect-reviewer` cree el draft PR.
- Escáneres del `guardian`: `semgrep`, `trivy`, `gitleaks` en el PATH.
- Los skills de lenguaje esperan las herramientas del stack (p. ej. `flutter`).

## Costo y modo económico

El pipeline puede consumir muchos tokens. Por defecto ya viene en **modo económico**:
todos los subagentes usan **Sonnet** (no Opus) y los que leen contexto tienen la
instrucción de ser frugales (no abrir archivos enormes; apoyarse en
`PROJECT_CONTEXT.md`). Recomendaciones para no quemar tu cuota:

- **Sesión en Sonnet**: corre `/model sonnet` antes de usar el flujo. El loop
  principal que orquesta también cuesta.
- **Adelgaza tu contexto**: `CLAUDE.md` de 15+ KB y `context.md` de 45 KB se pagan en
  cada turno. Deja en `CLAUDE.md` solo lo esencial y mueve el detalle a archivos que
  se lean bajo demanda. Corre `/eng-context` para tener un `PROJECT_CONTEXT.md` corto
  que los agentes usen en vez de re-leer todo.
- **Ve por etapas, no todo `/eng-flow` de golpe**: prueba primero solo el `analyst`
  (`usa el subagente analyst para el ticket DOKTA-123`). El `/eng-flow` completo
  encadena 7 agentes + loops (hasta 3 rojo-verde), y eso multiplica el gasto.
- **Sube a Opus solo donde importe**: si quieres máxima calidad en una etapa (p. ej.
  el `guardian` en un ticket de datos sensibles), cambia `model: sonnet` a
  `model: opus` en ese `agents/<agente>.md`. No lo pongas en todos.
- **Un ticket a la vez**: el `analyst` debe leer el ticket + un resumen, no el
  codebase. Si ves que abre archivos grandes, recórtale el alcance en su prompt.

## Relación con el orquestador Agent SDK

Este repo tiene dos formas del mismo equipo: este **plugin** (interactivo, en Claude
Code/VSCode) y el **orquestador sobre el Agent SDK** en `src/` (headless/CI, con
loops y gates programáticos). Comparten el diseño; usa el que encaje con el momento.
