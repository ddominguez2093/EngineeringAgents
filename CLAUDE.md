# CLAUDE.md

Este repo es un plugin de Claude Code: `plugins/engineering-agentic-flow/`. No hay
código de aplicación ni build; el producto son los prompts, los skills y dos scripts.

## Estructura
- `agents/` — seis subagentes. El campo `model` de cada uno es su modelo por defecto;
  `/eng-flow` lo sube a opus en el carril profundo.
- `commands/` — `/eng-flow` (orquestación) y `/eng-context` (preparar un repo).
- `skills/` — un skill por stack (`react-web`, `flutter`, `swift-ios`,
  `android-compose`, `spring-boot`) y `ponytail`.
- `scripts/verify.sh`, `scripts/scan.sh` — verificación y escáneres deterministas.
- `scripts/graph.sh` — grafo de código con graphify (opcional). Cómo consultarlo vive solo en `agents/scout.md`.
- `hooks/security-check.sh` — guardrail PreToolUse.

## Reglas al editar
- Cada línea de un agente, comando o skill se paga en cada corrida. Agrega solo lo
  que cambia el comportamiento del modelo; no expliques lo que ya sabe del stack.
- La `description` de un skill se carga siempre; el cuerpo solo al invocarlo. Mantén las descripciones en una o dos líneas.
- Una sola fuente por cosa: no dupliques un prompt o skill en otra carpeta.
- Los agentes se pasan rutas (`.agentflow/plans/<id>.md`, ramas), no contenido.
- Tras tocar un script o el hook, pruébalo: `bash -n`, y `verify.sh --list --all` en un repo real.

Diseño y motivos: `docs/AGENT_STRATEGY.md`.
