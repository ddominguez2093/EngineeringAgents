---
description: Continúa una corrida de /eng-flow que se cortó (límite de uso u otro motivo), desde el estado en disco y git, con el modelo o runtime que tengas disponible.
argument-hint: "[<id>]  (sin id: la corrida más reciente)"
---

Corrida a retomar: **$ARGUMENTS** (si viene vacío, usa `.agentflow/state.sh latest`).

Eres el orquestador de `/eng-flow`, pero **no empiezas de cero**: reconstruyes dónde
quedó la corrida desde disco y git, no desde ninguna conversación anterior.

## 1. Reconstruir
1. `.agentflow/state.sh show <id>`. Si no existe estado, no hay nada que retomar:
   dilo y sugiere `/eng-flow`.
2. Estás en el árbol correcto: la rama actual debe ser la del estado (`branch=`). Si
   no, `git checkout` esa rama. Si hay varios worktrees, el estado vive en el que se
   usó; trabaja ahí.
3. `git status --short` y `git log --oneline <base>..HEAD`.
   - Cambios sin commit: son trabajo a medias de la etapa cortada. Revísalos con
     `git diff` y haz `git add -A && git commit -m "wip(<id>): recuperado tras corte"`.
     Si están rotos, deja el commit WIP igual: el siguiente `coder` los corregirá.
4. Lee `.agentflow/plans/<id>.md` y compara las subtasks con los commits de la rama.
   La verdad es **git**: si el estado dice `subtasks_done=1` pero hay commits de la
   subtask 2, actualiza el estado a lo que git muestra.

## 2. Revisar si este modelo puede continuar
Anota quién retoma: `.agentflow/state.sh set <id> runtime=<runtime> note="retomado por <modelo>"`
y `.agentflow/state.sh log <id> resume ok <runtime>/<modelo>`.
- Carril **profundo** y la etapa pendiente es diseño, revisión o seguridad: si tu modelo
  es de menor nivel que el planeado (ver tabla de modelos del README), **no apruebes
  tú**: ejecuta la etapa, pero marca `last_verdict=…(modelo menor)` y pide revisión
  humana en el PR.
- El gate de diseño ya aprobado (`gate_design=aprobado`) no se pide otra vez. Si está
  `pendiente`, sigue pendiente: espera aprobación humana.

## 3. Continuar
Retoma en la **primera etapa incompleta** siguiendo `/eng-flow` (carril del estado,
no vuelvas a hacer triage):
- Subtasks: solo las que falten, en orden.
- Loops: usa los contadores del estado; no los reinicies. Si un loop ya agotó sus
  vueltas, aplica la regla de detenerse.
- Cada etapa nueva actualiza el estado y el log como en `/eng-flow`.

Primera línea de tu respuesta: `Retomando <id> en la etapa <etapa> (carril <carril>, hecho: <subtasks_done>)`.
