# Runbook — poner agentflow a correr

De "scaffold" a "ejecutable", en orden. Corre todo dentro de la carpeta del proyecto.

## 1. Dependencias

```bash
npm install
```

Instala el Agent SDK y el resto. (Se quitó `node_modules` del paquete; este paso lo repone.)

## 2. API key

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

## 3. Conectar Jira (Atlassian Rovo) — para el Analyst

El `.mcp.json` ya apunta al MCP de Atlassian. Autentícate una vez (abre OAuth en el navegador):

```bash
npx mcp-remote https://mcp.atlassian.com/v1/sse
```

## 4. Escáneres del Guardian

```bash
brew install semgrep trivy gitleaks
```

(Si falta alguno, el Guardian degrada esa comprobación pero avisa; no bloquea el arranque.)

## 5. Preflight

```bash
npx tsx src/index.ts doctor      # o: npm run doctor
```

Te dice exactamente qué falta (marcado con `--`). Resuélvelo hasta que lo esencial esté en `OK`.

## 6. El Librarian analiza el repo (de verdad)

```bash
npx tsx src/index.ts scan        # o: npm run scan
```

Escanea el workspace (y `legacy/` si es migración) y escribe `.agentflow/context/` + `docs/CAPABILITY_MATRIX.md`.

> Para tu migración: coloca el código iOS en `legacy/` antes de este paso, para que genere la matriz de paridad.

## 7. Correr el pipeline

```bash
npx tsx src/index.ts run PROJ-123   # o: npm run start PROJ-123
```

Corre Analyst → Architect → Gate A → (Coder ⇄ Tester) → Reviewer → Guardian → Gate B.
El log de cada corrida queda en `.agentflow/runs/<ticket>-<timestamp>/`.

## Empezar en pequeño (recomendado)

Antes del pipeline completo, valida UN agente:

```bash
npm run scan     # solo el Librarian: genera la matriz de capacidades de tu app iOS
```

Ese único paso ya te da valor y confirma que SDK + API + skills funcionan de punta a punta.
