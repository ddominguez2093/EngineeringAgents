---
description: El Librarian escanea el repo (y legacy/ en migraciones) y construye el cerebro del proyecto en .agentflow/context/.
argument-hint: (sin argumentos)
---

Invoca al subagente `librarian` para escanear este workspace y construir/actualizar
el "cerebro del proyecto".

Debe escribir en `.agentflow/context/`: architecture.md, conventions.md, ui-ux.md,
glossary.md y PROJECT_CONTEXT.md; detectar el stack y los comandos de build/test/lint.

Si existe una carpeta `legacy/` (migracion), ademas debe generar
`docs/CAPABILITY_MATRIX.md` con el soporte por plataforma de cada dependencia
(marcando gaps de Web) y extraer la spec de paridad de cada modulo.

Al terminar, resume que encontro (stack, arquitectura, y gaps criticos si es migracion).
