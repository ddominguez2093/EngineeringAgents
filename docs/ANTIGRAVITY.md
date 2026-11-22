# Usar el flujo en Antigravity

Para cuando se acaba tu uso de Claude: la misma estrategia (carriles, agentes, scripts,
gates) corre en Antigravity, y una corrida cortada se retoma con otro modelo.

## Instalar en un repo
```
git clone https://github.com/ddominguez2093/EngineeringAgents ~/dev/EngineeringAgents
~/dev/EngineeringAgents/scripts/sync-antigravity.sh /ruta/a/tu/repo      # --dry-run para ver qué haría
```
Es idempotente: repítelo cada vez que actualices el plugin. Genera, sin tocar tus archivos
(salvo `AGENTS.md`, donde solo agrega un bloque marcado):

| Genera | Qué es |
|---|---|
| `.agents/agents/*.md` | Los 6 subagentes. `haiku`→`flash`, `sonnet` y `opus`→`pro` (Antigravity solo tiene `inherit`, `flash`, `pro`). |
| `.agents/skills/` | Skills por stack, los tuyos de `.claude/skills`, y `/eng-flow`, `/eng-resume`, `/eng-context`, `/eng-graph`, `/eng-version`. |
| `.agents/rules/` | Tus `.claude/rules/*.md` con el `trigger` que Antigravity exige: `paths:` → `glob`; sin frontmatter → `always_on`. **Sin `trigger`, Antigravity descarta la regla sin avisar.** |
| `.agents/hooks.json` | El guardrail de seguridad y tus hooks `PreToolUse` de `.claude/settings.json`, vía `claude-hook-adapter.sh`. |
| `.agentflow/` | `verify.sh`, `scan.sh`, `graph.sh`, `state.sh`, `version.sh`, hooks. |
| `AGENTS.md` | Bloque con el flujo; si hay `CLAUDE.md`, lo incluye con `@[…](CLAUDE.md)` (una sola fuente). |

Luego, una vez por repo: `/eng-context`. Y para Jira, agrega el MCP de Atlassian en el gestor de MCP de Antigravity (o usa texto libre).

## Cuando se te acaba el uso de Claude
1. Claude no puede avisar con precisión antes del corte, por eso **el estado se escribe
   en cada etapa** (`.agentflow/state/<id>.state` + `.log`) y el `coder` hace commits `wip(...)`.
2. En Antigravity, en el **mismo repo/worktree**: `/eng-resume <id>` (sin id, la última corrida).
3. Reconstruye desde git (la verdad), recupera cambios sin commit y continúa en la primera
   etapa incompleta. Los loops no se reinician: sus contadores están en el estado.
4. El log registra qué modelo corrió cada etapa. Si el carril es **profundo** y un modelo
   menor hace diseño, revisión o seguridad, el PR lo marca para revisión humana.

Para seguir en otra máquina: haz push de la rama `feature/<id>` y copia `.agentflow/state/<id>.*`
(el estado es local; no va a git).

## Qué no se traduce solo
- **Permisos** (`permissions.allow/deny` de Claude): Antigravity usa su propia política de ejecución. El hook de seguridad cubre `rm -rf` sobre raíz/home, `curl | sh`, force-push a ramas principales y archivos de secretos (incl. `.key`); lo demás de tu `deny` (p. ej. `psql ... production`) hay que configurarlo en Antigravity.
- **Hooks distintos de `PreToolUse`** (PostToolUse, etc.): el payload es otro; se reportan como no convertidos.
- **Modelo por invocación**: en Claude, el carril profundo sube a `opus` al invocar. En Antigravity el modelo lo fija cada agente (`pro` para todos salvo scout y verifier).
- **MCP de Atlassian**: se configura en Antigravity.

## Verificado en la App de Antigravity
- Los hooks de `.agents/hooks.json` **sí se ejecutan** (confirmado para `run_command`). Se usan rutas **absolutas**: la ruta relativa no es fiable (el cwd del hook no está documentado).
- El evento trae `toolCall.name/args`, `cwd`, `workspacePaths`, `conversationId`, `modelName`, etc.
- Las herramientas de archivo de la App se llaman `read_file`, `write_file`, `edit_file` (la documentación habla de `view_file`, `write_to_file`, `replace_file_content`). El matcher y los scripts cubren ambas familias y clasifican por nombre.
- Depuración: crea `.agentflow/hook-debug` (o `AGENTFLOW_HOOK_DEBUG=1`) y mira `.agentflow/logs/hook-payloads.log`.

## Sin verificar (pruébalo la primera vez)
- Campo de ruta de `read_file`: verificado, es `Path` (con mayúscula). Falta confirmar el de `write_file`/`edit_file`.
- Si `invoke_subagent` permite elegir modelo por invocación (hoy no se usa).
- Que Antigravity ignore claves de skill que no conoce (p. ej. `disable-model-invocation`).

## ¿Estoy en la última versión?
- **Claude Code:** `/eng-version`, o `bash <plugin>/scripts/version.sh`. Compara versión y commit instalado con GitHub y avisa si los scripts de `.agentflow/` de tu repo están viejos. Alternativas: `claude plugin list` y `/plugin`.
- **Antigravity:** `bash .agentflow/version.sh` compara la copia generada con GitHub.
- Actualizar: `claude plugin marketplace update bitstream-agents && claude plugin update engineering-agentic-flow@bitstream-agents`, luego `/reload-plugins`; en Antigravity, `git pull` del clon y repetir el sync.
