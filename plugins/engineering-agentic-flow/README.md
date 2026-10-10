# engineering-agentic-flow

Plugin de Claude Code. Instalación, uso y carriles: ver el [README del repo](../../README.md).

| Carpeta | Contenido |
|---|---|
| `agents/` | `scout`, `planner`, `coder`, `verifier`, `reviewer`, `guardian` |
| `commands/` | `/eng-flow`, `/eng-context` |
| `skills/` | `react-web`, `flutter`, `swift-ios`, `android-compose`, `spring-boot`, `ponytail` |
| `scripts/` | `verify.sh` (lint, pruebas, build) y `scan.sh` (gitleaks, semgrep, trivy) |
| `security/` | Reglas Semgrep para Dart/Flutter |
| `hooks/` | Guardrail `PreToolUse` |
