---
description: Corre el flujo completo de ingenieria (Analyst -> Architect -> Coder+Tester -> Reviewer -> Guardian) para un ticket de Jira, con gates humanos.
argument-hint: <TICKET-ID>
---

Orquesta el equipo de ingenieria para el ticket **$1** (Jira). Delega en los
subagentes en este orden y respeta los gates. NO te saltes etapas.

## Disciplina de tokens (aplica a TODO el flujo)

- Al delegar, pasa a cada subagente SOLO el artefacto de la etapa previa
  (resumido si es largo), nunca el historial completo ni archivos enteros.
- Pide a cada subagente que devuelva YAML conciso; los diffs viven en git, no en
  los mensajes: reviewer/guardian corren `git diff` ellos mismos.
- No repitas en tu propio mensaje lo que el subagente ya reporto: una linea de
  estado por etapa basta.
- Para tickets pequenos y de bajo riesgo, sugiere usar `/eng-flow-lite` en su lugar.

## 1. Analyst
Invoca al subagente `analyst` para refinar el ticket **$1**. Si devuelve
`definitionOfReady: false` (hay openQuestions bloqueantes), DETENTE: reporta las
preguntas y pide al humano que las responda en Jira. No continues.

## 2. Architect
Invoca al subagente `architect` con el RefinedTicket. Obten el TechDesign (ADR),
las subtasks y el **riesgo** (low/medium/high).

## 3. GATE A (humano)
Muestra el diseno y las subtasks y **pide aprobacion explicita** antes de codear,
salvo que el riesgo sea `low` (fast lane). Si el humano pide cambios, regresa al
architect. No avances sin aprobacion en riesgo medium/high.

## 4. Loop rojo-verde (Coder <-> Tester), maximo 3 iteraciones
Por cada subtask: invoca `coder` para implementarla en una rama `feature/$1`, luego
`dev-tester` para escribir y CORRER las pruebas. Si las pruebas fallan, pasa el
output de vuelta al `coder`. Repite hasta verde o 3 iteraciones; si no converge,
para y escala (probable hueco de diseno).

## 5. Architect Reviewer (loop, maximo 2)
Invoca `architect-reviewer`. Si pide cambios, regresa al `coder` y re-revisa (hasta
2 veces). Al aprobar, deja creado el **draft PR**.

## 6. Guardian (loop de remediacion, maximo 2)
Invoca `guardian` sobre el PR. Si encuentra vulnerabilidades de severidad alta,
regresa al `coder` para remediar y re-escanea (hasta 2 veces). NUNCA apruebes
seguridad por agotamiento del loop: si sigue en fail, para y escala.

## 7. GATE B (humano)
Cuando el guardian de `pass`, presenta el PR listo. **El merge lo hace el humano.**

Guarda un breve log de cada etapa (veredictos y decisiones). Manten los mensajes
concisos entre etapas; el detalle vive en los artefactos de cada subagente.
