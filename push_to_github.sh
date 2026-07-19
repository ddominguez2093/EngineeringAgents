#!/usr/bin/env bash
#
# Sube EngineeringAgenticFlow a GitHub. Corre esto en TU terminal (no en Cowork),
# desde la carpeta del proyecto:
#
#   bash push_to_github.sh
#
# Requiere: git autenticado con GitHub (gh auth login, o un Personal Access Token,
# o SSH). El repo destino debe existir: https://github.com/ddominguez2093/EngineeringAgents
set -e

REMOTE="https://github.com/ddominguez2093/EngineeringAgents.git"

cd "$(dirname "$0")"

echo "==> Inicializando repositorio (si hace falta)"
git init -b main 2>/dev/null || { git init; git symbolic-ref HEAD refs/heads/main; }

echo "==> Identidad (ajusta si quieres otro nombre/email)"
git config user.email "ddominguezchavez@gmail.com"
git config user.name  "Daniel Dominguez"

echo "==> Agregando archivos (respetando .gitignore)"
git add -A

echo "==> Commit"
git commit -m "Initial commit: EngineeringAgenticFlow — equipo de ingenieria como agentes (Agent SDK)

Orquestador sobre el Claude Agent SDK: Analyst, Architect, Librarian, Coder
(ponytail), Dev Tester, Architect Reviewer y Guardian, con gates humanos, loops
acotados, hooks de seguridad, skills por lenguaje + ui-ux-pro-max, reglas Semgrep
Dart/Flutter y CI multiplataforma. Incluye el playbook de migracion iOS(VIPER)->Flutter." \
  || echo "(no habia cambios que commitear)"

echo "==> Remoto"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE"

echo "==> Push"
git branch -M main
if git push -u origin main; then
  echo "==> Listo: https://github.com/ddominguez2093/EngineeringAgents"
else
  cat <<'MSG'

El push fue rechazado. Casi siempre es porque el repo se creo con un README/licencia
inicial (historias distintas). Elige una:

  A) Traer ese commit y reintentar (conserva el README de GitHub):
       git pull --rebase origin main
       git push -u origin main

  B) Sobrescribir lo que haya en GitHub con esto (borra el README inicial):
       git push -u origin main --force

MSG
  exit 1
fi
