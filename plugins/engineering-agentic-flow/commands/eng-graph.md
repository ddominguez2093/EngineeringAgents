---
description: Construye o actualiza el grafo de código del repo con graphify y lo abre en el navegador (red interactiva y árbol por carpetas).
argument-hint: "(sin argumentos)"
---

1. Si no existe `.agentflow/graph.sh`, cópialo:
   `mkdir -p .agentflow && cp -n "${CLAUDE_PLUGIN_ROOT}"/scripts/*.sh .agentflow/`
2. Corre `.agentflow/graph.sh --global --html` y muestra su salida tal cual.
3. Si termina con error, muestra su salida tal cual y detente.

No leas `graph.json` ni los HTML: son para que la persona los vea en el navegador.
