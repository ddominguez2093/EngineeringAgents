# EngineeringAgenticFlow — Estrategia de Agentes

> Un "equipo de ingeniería" completo, implementado como agentes especializados sobre el **Claude Agent SDK**, que lleva un ticket de Jira desde el refinamiento hasta un Pull Request seguro y probado — con el merge final siempre en manos humanas.

Documento de diseño · v1.0 · Autor: Daniel (Bitstream Labs) · Runtime objetivo: Claude Agent SDK (TypeScript)

---

## 1. Resumen ejecutivo

Tu idea original es sólida: modelar el ciclo de vida de una feature como una cadena de agentes especializados (Analyst → Architect → Coder → Tester → Architect Reviewer → Guardian) con un Librarian que da contexto y un sistema de skills para volver a los agentes expertos por lenguaje.

Este documento la conserva íntegra y le agrega siete cosas que, en mi experiencia, son las que separan un demo bonito de un sistema que puedes dejar corriendo sin que te meta bugs o vulnerabilidades:

1. **Contratos entre etapas** (artefactos estructurados y validables), no "el agente le pasa texto al siguiente".
2. **Verificación con herramientas reales**, no solo razonamiento del LLM: el Tester *corre* las pruebas; el Guardian *ejecuta* SAST/escáneres (Semgrep, Trivy, gitleaks, `npm audit`).
3. **Loops acotados con presupuesto**: dónde sí valen la pena (Coder⇄Tester, Reviewer→Coder, Guardian→Coder) y dónde son una trampa (Analyst consigo mismo).
4. **Gates humanos en los dos puntos de máximo apalancamiento**, no en cada paso.
5. **Ruteo por riesgo**: un cambio de copy no pasa por el mismo camino que tocar el módulo de pagos.
6. **Aislamiento y auditoría**: cada corrida en su rama/worktree, con un log de auditoría de cada veredicto.
7. **Tiering de modelos** para controlar costo (Haiku/Sonnet para lo mecánico, Opus para lo que decide arquitectura o seguridad).

El resultado es instalable en cualquier workspace con un solo comando (`agentflow init`), funciona tanto en un repo existente como en un proyecto nuevo, y el Librarian mantiene un "cerebro del proyecto" persistente para que los agentes no re-descubran el contexto en cada corrida.

---

## 2. Principios de diseño

**Contratos, no conversaciones.** Cada agente produce un artefacto con esquema fijo (YAML/JSON) que el siguiente consume. Esto hace cada handoff *inspeccionable* y *bloqueable*: si el artefacto no cumple su "Definition of Ready/Done", el pipeline se detiene o hace loop. Los agentes conversan por necesidad, pero el estado del pipeline vive en artefactos, no en el historial de chat.

**La verificación es determinista siempre que se pueda.** Un LLM es excelente proponiendo y pésimo garantizando. Por eso el Tester no "cree" que las pruebas pasan: las ejecuta y adjunta el output. El Guardian no "opina" que no hay SQL injection: corre Semgrep con reglas OWASP y adjunta el reporte. El LLM interpreta y prioriza; las herramientas dan el veredicto duro.

**Aislamiento de contexto por agente.** El SDK corre cada subagente en una conversación fresca; solo su mensaje final vuelve al orquestador. El Coder puede leer 40 archivos sin contaminar el contexto del Guardian. Cada agente recibe exactamente el artefacto que necesita, no toda la historia.

**Mínimo privilegio.** Cada agente declara solo las tools que necesita. El Analyst y los reviewers son *read-only* (`Read`, `Grep`, `Glob`) más su MCP. Solo el Coder tiene `Edit`/`Write`. El Guardian tiene `Bash` para correr escáneres pero no puede escribir código.

**Humano en el lazo donde cambiar de opinión es barato.** El punto más caro para corregir el rumbo es después de mergear; el más barato es después de que el Architect propone la solución. Ahí ponemos el gate principal.

**Instalable y portátil.** Toda la configuración vive en `.agentflow/` dentro del repo. Clonas el repo, corre `agentflow init`, y el equipo de agentes ya conoce tu stack, tus convenciones y tu arquitectura.

---

## 3. Crítica y mejoras a la idea original

| Tu idea | Qué conservo | Qué agrego / cambio |
|---|---|---|
| Analyst analiza el ticket de Jira con Rovo y encuentra gaps | Todo | Produce un **Ticket Refinado** con esquema fijo (criterios de aceptación, reglas de negocio, preguntas abiertas, clasificación de riesgo). Si hay gaps de *negocio*, **escala al humano**, no inventa. |
| Architect propone solución y crea subtasks | Todo | La solución es un **ADR + plan de subtasks** validable. El Architect también **etiqueta el riesgo** (low/med/high) que decide cuántos gates aplican. |
| Coder implementa (estilo ponytail) | Todo | ponytail entra como **skill preload** (filosofía de minimalismo/reuso), no como agente. El Coder trabaja en una **rama/worktree aislada**. |
| Dev Tester implementa pruebas unitarias | Todo | Forma un **loop rojo-verde con el Coder**: escribe pruebas, las *corre*, y los fallos regresan al Coder (acotado). Reporta cobertura real. |
| Architect Reviewer revisa antes del PR | Todo | Emite un **veredicto** (approve/request-changes) con contrato. Si pide cambios, loop acotado de vuelta al Coder. Al aprobar, crea el **draft PR**. |
| Guardian revisa seguridad (OWASP) | Todo | LLM **+ herramientas reales** (Semgrep, Trivy, gitleaks, audit de dependencias). Veredicto bloqueante. Si hay hallazgo crítico, loop de remediación al Coder. |
| Librarian da contexto (arquitectura, patrones, UI/UX) | Todo | Se vuelve el **"cerebro del proyecto" persistente**: indexa una vez, mantiene `PROJECT_CONTEXT.md`, y **todos** los agentes lo leen. No re-descubre el contexto cada corrida. |
| Skills por lenguaje (Java, C#, Kotlin, Swift, Flutter, RN…) | Todo | Sistema de **skill packs** versionados. Se atan al Coder/Tester **según el stack detectado** o declarado, dinámicamente. |
| — | — | **Orchestrator** explícito (nuevo): conduce el pipeline, gestiona artefactos, gates, loops, reintentos y el log de auditoría. |

### Lo que quité o moví a propósito

- **ponytail como agente separado**: sería redundante. Su valor es una heurística de "no sobre-ingenierizar", que aplica *mientras* el Coder escribe. Va como skill del Coder y como criterio del Architect Reviewer (`/ponytail-review` audita el diff buscando sobre-ingeniería).
- **Un "loop" del Analyst consigo mismo**: no lo pongas. Los gaps que el Analyst encuentra son casi siempre de *negocio* (falta una regla, un caso borde no definido). Eso no lo resuelve iterando el LLM; lo resuelve una persona. El Analyst hace *una* pasada profunda y escala lo que no puede cerrar.

---

## 4. El roster de agentes

Ocho piezas: siete agentes especializados + el orquestador que los coordina.

### 4.0 Orchestrator (el director)
No es un LLM que "piensa"; es el script que ejecuta el pipeline. Decide qué agente corre, con qué artefacto de entrada, aplica los gates, administra los loops y su presupuesto, escribe el log de auditoría y persiste el estado para poder reanudar (`resume`). En el SDK esto es tu código TypeScript llamando a `query()` con distintas `AgentDefinition`. Para corridas muy grandes, el SDK ofrece el `Workflow` tool, pero para un pipeline lineal con loops acotados, orquestar turno a turno es más simple y transparente.

### 4.1 Analyst — Refinador de requerimientos
- **Entrada**: ID de ticket de Jira.
- **Herramientas**: MCP de Atlassian/Rovo (`getJiraIssue`, `search`, `getConfluencePage`, `addCommentToJiraIssue`), `Read`/`Grep` para ver el código existente relacionado.
- **Qué hace**: lee el ticket y el contexto (Confluence, tickets relacionados, código actual vía Librarian), detecta gaps, ambigüedad y lógica de negocio no definida.
- **Salida — `refined-ticket.yaml`**: título, contexto, criterios de aceptación (Given/When/Then), reglas de negocio explícitas, dependencias, **preguntas abiertas bloqueantes**, clasificación preliminar de riesgo, y "Definition of Ready" (¿está listo para que el Architect lo tome?).
- **Escalamiento**: si hay preguntas abiertas bloqueantes, comenta el ticket en Jira y **detiene el pipeline** hasta que el humano responda. Este es el único "loop" del Analyst y es con una persona, no consigo mismo.
- **Modelo**: Opus o Sonnet (razonamiento de negocio; vale la pena).

### 4.2 Architect — Diseñador de la solución
- **Entrada**: `refined-ticket.yaml` + `PROJECT_CONTEXT.md` del Librarian.
- **Herramientas**: `Read`, `Grep`, `Glob` (read-only sobre el código), MCP de Jira para crear subtasks.
- **Qué hace**: propone la solución técnica *más adecuada al proyecto* (respetando arquitectura y patrones existentes que le da el Librarian), documenta el porqué, y descompone en subtasks accionables para el Coder.
- **Salida — `tech-design.md` (ADR) + `subtasks.yaml`**: decisión y alternativas descartadas con su razón, componentes afectados, contratos/interfaces nuevas, plan de pruebas esperado, **clasificación de riesgo final** (low/med/high), y las subtasks con orden y criterios de aceptación por subtask.
- **Modelo**: Opus (aquí se decide la calidad de todo lo que sigue).
- **Gate**: aquí va el **gate humano principal** (ver §6).

### 4.3 Librarian — El cerebro del proyecto
- **Entrada**: el workspace completo (una vez en `init`, y de forma incremental después).
- **Herramientas**: `Read`, `Grep`, `Glob`, `Bash` (para árbol de archivos, detectar package managers, etc.).
- **Qué hace**: construye y mantiene un modelo persistente del proyecto: arquitectura y capas, patrones de diseño en uso, convenciones de código, stack y build/test commands, estilo de UI/UX, glosario de dominio, y "cómo se hacen las cosas aquí".
- **Salida — `.agentflow/context/PROJECT_CONTEXT.md`** (+ sub-docs: `architecture.md`, `conventions.md`, `ui-ux.md`, `glossary.md`). Es leído por **todos** los demás agentes como contexto base.
- **Cuándo corre**: en `init`, y luego incrementalmente después de cada merge (o bajo demanda) para no quedar desactualizado. No corre en cada etapa del pipeline: eso sería caro y lento. Los agentes *leen* su salida.
- **Modelo**: Sonnet para el indexado incremental; Opus para la primera pasada de un repo grande. En proyecto nuevo (greenfield) el Librarian arranca casi vacío y *aprende* conforme el equipo produce las primeras features.

### 4.4 Coder — Implementador (filosofía ponytail)
- **Entrada**: una subtask de `subtasks.yaml` + `tech-design.md` + `PROJECT_CONTEXT.md`.
- **Herramientas**: `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`. **Skills**: `ponytail` (siempre) + el skill del lenguaje del stack.
- **Qué hace**: implementa la subtask con el mínimo código necesario, reusando lo que ya existe (la "escalera de decisión" de ponytail: ¿ya existe? ¿stdlib? ¿nativo? ¿dependencia instalada? ¿una línea? → solo entonces, implementación mínima). Nunca sacrifica validación en fronteras de confianza, manejo de errores, seguridad ni accesibilidad.
- **Salida — diff en la rama + `changelog.md`**: qué archivos tocó, decisiones, y qué dejó fuera a propósito.
- **Modelo**: Sonnet por defecto (buen costo/calidad para código); Opus para subtasks marcadas high-risk.
- **Aislamiento**: trabaja en `feature/<ticket>` (o git worktree) para no tocar `main`.

### 4.5 Dev Tester — Ingeniero de pruebas
- **Entrada**: el diff del Coder + `tech-design.md` (plan de pruebas esperado) + skill del lenguaje.
- **Herramientas**: `Read`, `Write`, `Edit`, `Bash` (corre el framework de pruebas del stack), `Grep`.
- **Qué hace**: escribe pruebas unitarias (y de integración cuando aplica) para lo que implementó el Coder, **las ejecuta**, y reporta resultados y cobertura reales.
- **Salida — `test-report.yaml`**: pruebas añadidas, resultado de la corrida (pass/fail con output), cobertura, y casos borde que faltan.
- **Loop**: si las pruebas fallan, el fallo (con el output real) regresa al Coder → *loop rojo-verde acotado* (ver §5).
- **Modelo**: Sonnet.

### 4.6 Architect Reviewer — Revisor arquitectónico
- **Entrada**: diff + `test-report.yaml` + `tech-design.md` + `PROJECT_CONTEXT.md`.
- **Herramientas**: `Read`, `Grep`, `Glob`, MCP/`gh` para crear el draft PR. Skill: `ponytail-review` (audita sobre-ingeniería).
- **Qué hace**: verifica que la implementación respete el diseño aprobado y las convenciones del proyecto, que no introduzca deuda arquitectónica, y que las pruebas sean significativas (no cobertura de mentira).
- **Salida — `review-verdict.yaml`**: `approved` | `changes_requested`, con lista de hallazgos priorizados.
- **Loop**: si `changes_requested`, regresa al Coder (acotado). Si `approved`, **crea el draft PR** y pasa al Guardian.
- **Modelo**: Opus (juicio arquitectónico).

### 4.7 Guardian — Guardián de seguridad
- **Entrada**: el draft PR / diff.
- **Herramientas**: `Read`, `Grep`, `Bash` (para correr las herramientas), MCP/`gh`. **Sin** `Write`/`Edit` (no arregla, dictamina).
- **Qué hace**: análisis de seguridad en dos capas. (a) **Determinista**: corre Semgrep (reglas OWASP Top 10 + del lenguaje), Trivy/`npm audit`/dependency scanning, gitleaks (secretos), y linters de seguridad del stack. (b) **Razonamiento LLM**: interpreta los hallazgos, descarta falsos positivos con contexto, y busca vulnerabilidades lógicas que las herramientas no ven (authz rota, IDOR, mass assignment, etc.).
- **Salida — `security-verdict.yaml`**: `pass` | `fail`, hallazgos con severidad (CVSS/OWASP category), y evidencia (output de las herramientas).
- **Loop**: si `fail` con severidad ≥ alta, regresa al Coder para remediación (acotado). Si `pass`, marca el PR como listo para revisión humana.
- **Gate**: aquí termina el pipeline autónomo. **El merge lo haces tú** (§6, Gate final).
- **Modelo**: Opus (seguridad es donde menos quieres ahorrar).

---

## 5. Loops: dónde sí, dónde no, y con qué presupuesto

Los loops son la diferencia entre un pipeline que "hace su mejor intento" y uno que *converge a algo correcto*. Pero un loop sin presupuesto es un incendio de tokens (y a veces de bugs). Regla: **todo loop tiene un presupuesto de iteraciones y una salida a humano cuando se agota.**

**Loop 1 — Coder ⇄ Tester (rojo-verde).** El de mayor valor. El Coder implementa; el Tester escribe pruebas y las corre; los fallos vuelven al Coder con el output real. Converge cuando las pruebas pasan. Presupuesto sugerido: **3 iteraciones**. Si no converge, escala: probablemente el diseño tiene un hueco → de vuelta al Architect o al humano.

**Loop 2 — Architect Reviewer → Coder.** Si el reviewer pide cambios, el Coder los aplica y el reviewer re-revisa. Presupuesto: **2 iteraciones**. Si sigue rechazando, escala a humano (señal de que diseño e implementación no se entienden).

**Loop 3 — Guardian → Coder (remediación).** Hallazgo crítico → el Coder remedia → el Guardian re-escanea. Presupuesto: **2 iteraciones**. Si persiste, **para y escala siempre** (nunca auto-apruebes seguridad por agotamiento del loop).

**Dónde NO poner loops:**
- **Analyst consigo mismo**: los gaps de negocio los cierra una persona, no otra iteración del LLM. Su "loop" es con el humano vía comentario en Jira.
- **Architect en bucle infinito de rediseño**: una propuesta buena + el gate humano. Si el humano rechaza, el humano da la dirección; no dejes al Architect adivinando.

**Sobre `/loop` (auto-agendado):** vale la pena para lo *asíncrono*: por ejemplo, un agente que cada mañana revisa tickets nuevos en Jira que estén "Ready for Refinement" y dispara el Analyst automáticamente, dejándote los tickets refinados para cuando llegas. Eso lo montamos como **tarea programada** (no como un loop apretado). Para el pipeline en sí, los loops acotados internos son suficientes; no necesitas re-despertar la sesión.

---

## 6. Autonomía recomendada (mi recomendación)

Elegiste "que yo recomiende". Mi recomendación es un **modelo híbrido con ruteo por riesgo**: los loops internos corren 100% autónomos, y hay exactamente **dos gates humanos obligatorios** en los puntos de máximo apalancamiento. No más, porque un gate en cada paso mata la velocidad que buscas; no menos, porque cambiar de dirección después del merge es carísimo.

**Gate A — Aprobación de diseño (después del Architect).** Es el gate de oro. Aquí, por unos minutos de tu tiempo, apruebas o corriges: (1) el ticket refinado y (2) la solución + subtasks. Corregir el rumbo aquí cuesta minutos; corregirlo después de codear cuesta horas. **Obligatorio para riesgo medio/alto.**

**Gate B — Merge final (después del Guardian).** Ya lo querías así. El pipeline te entrega un PR probado, revisado arquitectónicamente y con veredicto de seguridad limpio. Tú lees el PR y haces el merge. **Siempre humano, sin excepción.**

**Todo lo de en medio** (Coder ↔ Tester ↔ Reviewer ↔ Guardian, con sus loops) corre **autónomo**.

**Ruteo por riesgo** (el Architect etiqueta):
- **Low** (copy, config trivial, cambio aislado con pruebas): puede saltarse el Gate A → fast lane. Igual pasa por Tester + Guardian.
- **Medium**: Gate A obligatorio.
- **High** (auth, pagos, datos sensibles, migraciones): Gate A obligatorio **+** el Guardian corre en modo estricto **+** revisión humana reforzada del PR. Coder y subtasks high-risk usan Opus.

**Cómo crece la confianza:** empieza con Gate A obligatorio para *todo*. Cuando lleves N features sin sorpresas, mueve los tickets "low" al fast lane. El sistema está diseñado para que subas la autonomía por clase de riesgo, no de golpe.

---

## 7. Sistema de skills (expertos por lenguaje)

Un **skill pack** es una carpeta con un `SKILL.md` (y archivos de referencia) que enseña a un agente cómo trabajar en un stack: framework de pruebas y cómo correrlo, convenciones idiomáticas, comandos de build/lint, gotchas de seguridad del lenguaje, y patrones preferidos.

```
skills/
  ponytail/            # filosofía de minimalismo (siempre en el Coder)
  java/                # JUnit, Maven/Gradle, Spring conventions…
  csharp/              # xUnit/NUnit, dotnet, async patterns…
  kotlin-android/      # JUnit+Espresso, Gradle, Jetpack, lifecycle…
  swift-ios/           # XCTest, SwiftPM, VIPER/MVVM, concurrency…
  flutter-dart/        # flutter test, widget tests, state mgmt…
  react-native/        # Jest+RTL, Metro, native modules…
```

**Cómo se atan:** el Librarian detecta el stack en `init` y lo escribe en `.agentflow/config.yaml`. El orquestador ata dinámicamente el/los skill(s) correspondientes al Coder y al Tester vía el campo `skills` de la `AgentDefinition`. Un monorepo con backend Java y app Flutter puede activar ambos y rutear por subtask.

**Reuso de lo que ya tienes:** ya cuentas con un skill `swift-viper-reviewer` muy detallado. Ese patrón (revisor senior + reglas VIPER + fixes) es exactamente el molde para `swift-ios`, y muestra que el Architect Reviewer y el Guardian también pueden recibir skills específicos del stack, no solo el Coder.

**Extensible:** agregar un lenguaje = agregar una carpeta con su `SKILL.md`. Sin tocar el orquestador.

---

## 8. El "cerebro del proyecto" (Librarian) y la instalación

**Instalable en cualquier workspace.** Todo vive en `.agentflow/` dentro del repo:

```
.agentflow/
  config.yaml            # stack, gates por riesgo, presupuestos de loop, modelos
  context/
    PROJECT_CONTEXT.md    # índice maestro (lo leen todos los agentes)
    architecture.md
    conventions.md
    ui-ux.md
    glossary.md
  runs/                   # log de auditoría por corrida (artefactos + veredictos)
```

**`agentflow init`** hace: (1) el Librarian escanea el repo, detecta stack y build/test commands, e infiere arquitectura, patrones y estilo; (2) escribe `PROJECT_CONTEXT.md` y `config.yaml`; (3) en un repo *existente*, aprende de lo que hay; en un proyecto *nuevo*, hace preguntas mínimas (¿qué stack? ¿qué convención de commits?) y arranca un contexto semilla que crece con las primeras features.

**Auditoría.** Cada corrida escribe en `runs/<ticket>-<timestamp>/` todos los artefactos y veredictos. Esto te da trazabilidad (quién decidió qué y por qué), es oro para postmortems, y es la evidencia de que el Guardian efectivamente corrió y pasó — importante si algún día necesitas mostrar cumplimiento.

---

## 9. Seguridad del propio sistema (no solo del código que produce)

Un equipo de agentes con `Bash` y `Write` es poderoso y peligroso. Salvaguardas incorporadas:

- **Hooks `PreToolUse`** (a nivel del SDK) que bloquean comandos peligrosos antes de ejecutarse: `rm -rf` fuera del workspace, `curl | sh`, escrituras a `.env`/secretos, `git push --force` a `main`, instalación de dependencias no declaradas. El Guardian define la política; el hook la aplica de forma determinista.
- **Mínimo privilegio por agente** (ya en §2): reviewers y Analyst son read-only; solo Coder escribe; Guardian no escribe.
- **Aislamiento de rama/worktree**: el Coder nunca toca `main`; el merge es humano.
- **Secretos**: gitleaks en el Guardian + hook que impide leer/commitear archivos de credenciales.
- **Sandbox**: el pipeline corre en el contenedor efímero (o un worktree aislado), no directo sobre tu entorno.

---

## 10. Tiering de modelos y costo

| Agente | Modelo sugerido | Por qué |
|---|---|---|
| Analyst | Opus / Sonnet | Razonamiento de negocio, detectar gaps |
| Architect | **Opus** | Decide la calidad de todo lo que sigue |
| Librarian | Sonnet (incremental) / Opus (primera pasada) | Indexado; mayormente mecánico |
| Coder | Sonnet (Opus si high-risk) | Buen costo/calidad para código |
| Tester | Sonnet | Escribir y correr pruebas |
| Architect Reviewer | **Opus** | Juicio arquitectónico |
| Guardian | **Opus** | Seguridad: no ahorres aquí |

Regla simple: **Opus donde se decide o se dictamina; Sonnet donde se ejecuta; Haiku para tareas triviales de clasificación/routing** si las agregas.

---

## 11. Roadmap sugerido

**Fase 1 — Núcleo end-to-end (1 stack).** Orchestrator + los 7 agentes + `agentflow init` + Librarian básico, para un solo lenguaje (elige el de tu proyecto real más activo). Gate A y Gate B obligatorios para todo. Sin ruteo por riesgo todavía.

**Fase 2 — Verificación dura + loops.** Integra Semgrep/Trivy/gitleaks en el Guardian y la corrida real de pruebas en el Tester. Activa los loops acotados (rojo-verde, review, remediación) con sus presupuestos.

**Fase 3 — Skills multi-lenguaje + ruteo por riesgo.** Agrega los skill packs restantes, el atado dinámico por stack, y el fast lane para tickets low-risk.

**Fase 4 — Asíncrono y escala.** Tarea programada que dispara el Analyst sobre tickets nuevos de Jira; log de auditoría enriquecido; métricas (lead time por etapa, tasa de rechazo del Guardian, iteraciones promedio por loop).

---

## 12. Diagrama de flujo

Ver `docs/FLOW.mermaid`. Resumen textual:

```
Jira ticket
   │
   ▼
[Analyst] ──(gaps de negocio?)──► comenta Jira ─► ⏸ espera humano
   │  refined-ticket.yaml
   ▼
[Architect] ─► tech-design.md + subtasks.yaml + riesgo
   │
   ▼
  ⟦ GATE A: aprobación humana de diseño ⟧   (saltable si low-risk)
   │
   ▼
 ┌───────────── loop rojo-verde (≤3) ─────────────┐
 │ [Coder] ─diff─► [Tester] ─fail─► de vuelta      │
 └───────────────────────┬────────────────────────┘
                         │ pruebas verdes
                         ▼
 [Architect Reviewer] ─changes?─► Coder (≤2) ── approve ─► draft PR
                         │
                         ▼
 [Guardian] ─fail crítico─► Coder (≤2) ── pass ─► PR listo
                         │
                         ▼
              ⟦ GATE B: merge humano ⟧
```

---

## 13. Cómo se ve en el Agent SDK (referencia rápida)

Cada agente es una `AgentDefinition` (`description`, `prompt`, `tools`, `model`, `skills`, `mcpServers`, `permissionMode`, `maxTurns`). El orquestador los invoca con `query()`, pasando el artefacto de la etapa previa como prompt. La comunicación entre agentes usa el tool `SendMessage`; la seguridad de ejecución usa hooks `PreToolUse`; la reanudación usa `resume` con el `session_id`. Todo esto está implementado en el scaffold que acompaña este documento (`src/`).
