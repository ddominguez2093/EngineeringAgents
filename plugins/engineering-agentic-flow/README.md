# engineering-agentic-flow

Plugin de Claude Code. Instalación, uso y carriles: ver el [README del repo](../../README.md).

| Carpeta | Contenido |
|---|---|
| `agents/` | `scout`, `planner`, `coder`, `verifier`, `reviewer`, `guardian` |
| `commands/` | `/eng-flow`, `/eng-context` |
| `skills/` | `react-web`, `flutter`, `swift-ios`, `android-compose`, `spring-boot`, `ponytail` |
| `scripts/` | `verify.sh` (lint, pruebas, build), `scan.sh` (gitleaks, semgrep, trivy) y `graph.sh` (grafo de código con graphify) |
| `security/` | Reglas Semgrep para Dart/Flutter |
| `hooks/` | Guardrail `PreToolUse` |
