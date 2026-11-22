# AGENTS.md

Este repo es un plugin de Claude Code que también corre en Antigravity:
`plugins/engineering-agentic-flow/`. No hay código de aplicación ni build; el producto
son los prompts, los skills y unos pocos scripts. (`CLAUDE.md` solo importa este archivo.)

## Estructura
- `agents/` — seis subagentes. El campo `model` de cada uno es su modelo por defecto;
  `/eng-flow` lo sube a opus en el carril profundo.
- `commands/` — `/eng-flow` (orquestación), `/eng-resume` (retomar una corrida cortada),
  `/eng-context` (preparar un repo), `/eng-graph` (ver el grafo) y `/eng-version`.
- `skills/` — un skill por stack (`react-web`, `flutter`, `swift-ios`,
  `android-compose`, `spring-boot`) y `ponytail`.
- `scripts/verify.sh`, `scripts/scan.sh` — verificación y escáneres deterministas.
- `scripts/graph.sh` — grafo de código con graphify (obligatorio; el flujo se detiene sin él). Cómo consultar el grafo y token-goat vive solo en `agents/scout.md`.
- `scripts/state.sh` — estado de cada corrida (`.agentflow/state/<id>.state`), la base del relevo entre modelos.
- `scripts/version.sh` — compara la versión en uso con GitHub y detecta scripts viejos en un repo.
- `hooks/security-check.sh` — guardrail PreToolUse; entiende el formato de Claude Code y el de Antigravity.
- `hooks/claude-hook-adapter.sh` — corre en Antigravity un hook de Claude Code tal cual.
- `/scripts/sync-antigravity.sh` (raíz del repo) — genera `.agents/` en otro repo a partir del plugin. Ver `docs/ANTIGRAVITY.md`.

## Reglas al editar
- Cada línea de un agente, comando o skill se paga en cada corrida. Agrega solo lo
  que cambia el comportamiento del modelo; no expliques lo que ya sabe del stack.
- La `description` de un skill se carga siempre; el cuerpo solo al invocarlo. Mantén las descripciones en una o dos líneas.
- Una sola fuente por cosa: no dupliques un prompt o skill en otra carpeta. Lo de
  Antigravity se **genera** desde `agents/`, `commands/` y `skills/`; no se edita a mano.
- Los agentes se pasan rutas (`.agentflow/plans/<id>.md`, ramas), no contenido.
- El estado de una corrida vive en archivos y git, nunca solo en la conversación: otro
  modelo debe poder continuar. Toda etapa nueva actualiza `state.sh`.
- No pongas en un agente o comando nada que solo exista en Claude Code sin decirlo: el
  generador sabe traducir `Read/Grep/Glob/Edit/Write/Bash/Skill`, `model` y `$ARGUMENTS`.
- Tras tocar un script o el hook, pruébalo: `bash -n`, y `verify.sh --list --all` en un repo real.
  Tras tocar el generador, corre `scripts/sync-antigravity.sh --dry-run <repo>`.
- Cada release cambia `version` en `plugin.json`; sin eso Claude Code no baja los commits.

Diseño y motivos: `docs/AGENT_STRATEGY.md`.
