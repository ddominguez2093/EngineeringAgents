---
description: Construye o actualiza el grafo de conocimiento del repo (código y documentación) con graphify y lo abre en el navegador.
argument-hint: "[--relabel]"
---

1. Copia los scripts del plugin, siempre (así se actualizan con el plugin):
   `mkdir -p .agentflow && cp "${CLAUDE_PLUGIN_ROOT}"/scripts/*.sh "${CLAUDE_PLUGIN_ROOT}"/security/semgrep-flutter.yml .agentflow/`
2. Corre `.agentflow/graph.sh --global --html $ARGUMENTS` con timeout de 600000 ms (la primera construcción en modo completo puede tardar varios minutos; si se corta, vuelve a correrlo: retoma desde la caché), y muestra su salida tal cual.
3. Si termina con error, muestra su salida tal cual y detente.

No leas `graph.json` ni los HTML: son para que la persona los vea en el navegador.
