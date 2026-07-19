#!/usr/bin/env bash
#
# Instala EngineeringAgenticFlow en cualquier workspace.
#
# Uso:
#   ./scripts/install.sh /ruta/a/mi/repo
#
# Copia el runtime de agentes, instala dependencias y corre `agentflow init`
# para que el Librarian analice el repo destino.

set -euo pipefail

TARGET="${1:-$(pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Instalando agentflow en: $TARGET"

# 1) Runtime de agentes: skills y config del SDK van en .claude/ (donde el SDK los descubre).
mkdir -p "$TARGET/.agentflow"
cp -R "$HERE/.claude" "$TARGET/.claude"
[ -f "$HERE/.mcp.json" ] && cp "$HERE/.mcp.json" "$TARGET/.mcp.json"

# 2) Dependencias del SDK.
if [ ! -f "$TARGET/package.json" ]; then
  echo "==> No hay package.json en el destino; agentflow correra como paquete global."
fi
( cd "$HERE" && npm install --silent )

# 3) Requiere ANTHROPIC_API_KEY en el entorno.
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "!! Falta ANTHROPIC_API_KEY. Exportala antes de correr agentflow."
fi

# 4) Inicializa y verifica.
( cd "$TARGET" && npx tsx "$HERE/src/index.ts" init && npx tsx "$HERE/src/index.ts" doctor )

echo "==> Listo. Resuelve lo que marque 'doctor', luego: agentflow scan && agentflow run <TICKET>"
