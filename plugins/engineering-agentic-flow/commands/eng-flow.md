---
description: Lleva un ticket de Jira o una tarea descrita hasta un PR en borrador, eligiendo el carril (rápido, estándar o profundo) y el modelo de cada etapa según el riesgo.
argument-hint: "[--rapido|--estandar|--profundo] <TICKET-ID o descripción de la tarea>"
---

Tarea: **$ARGUMENTS**

Eres el orquestador. Tu contexto es el recurso más caro del flujo: delega la lectura
y las salidas largas, y conserva solo decisiones y veredictos.

## Reglas de contexto (aplican a todo el flujo)
- El plan vive en `.agentflow/plans/<id>.md` y el código en git. A cada subagente le
  pasas **rutas**, no contenido: el plan, el número de subtask y la rama base.
- No leas diffs, logs ni archivos de código en el carril estándar o profundo; para eso están los subagentes.
- No repitas lo que un subagente reportó. Una línea de estado por etapa.
- Cada subagente arranca sin memoria: dale en el mensaje todo lo que necesita (ruta
  del plan, subtask, base, y los hallazgos textuales si es una corrección).

## 0. Preparación
- Si no existe `.agentflow/verify.sh`, créalo:
  `mkdir -p .agentflow && cp "${CLAUDE_PLUGIN_ROOT}"/scripts/verify.sh "${CLAUDE_PLUGIN_ROOT}"/scripts/scan.sh "${CLAUDE_PLUGIN_ROOT}"/security/semgrep-flutter.yml .agentflow/`
- Identifica la rama base (`main`, `master` o `develop`) y define `<id>`: el ID del
  ticket, o un slug corto de la descripción.

## 1. Triage (tú, sin subagentes)
Si el argumento trae `--rapido`, `--estandar` o `--profundo`, usa ese carril. Si no,
lee el ticket o la descripción y elige:

| Carril | Cuándo |
|---|---|
| **rápido** | Cambio localizado y evidente: texto, estilo, configuración, un bug con causa conocida, hasta ~3 archivos de un solo stack, sin lógica de negocio nueva. |
| **profundo** | Toca autenticación o autorización, pagos, datos personales, migraciones de datos o esquema, contratos de API públicos, concurrencia, o más de un stack a la vez. |
| **estándar** | Todo lo demás. |

En la duda entre dos carriles, elige el más alto. Di en una línea qué carril
elegiste y por qué, y continúa sin pedir permiso.

## Carril rápido
1. Crea la rama `feature/<id>`. Haz el cambio tú mismo, cargando el skill del stack
   si vas a escribir lógica. Incluye o ajusta la prueba que lo cubre.
2. Corre `.agentflow/verify.sh --quick <base>`. Si falla, arregla una vez.
3. Si al trabajar descubres que no era tan simple (más archivos, lógica de negocio,
   algo de la lista del carril profundo), detente y sube de carril.
4. Commit y PR en borrador (paso final).

## Carril estándar
1. **Plan.** Invoca `planner` con la tarea. Si no sabes dónde vive el código y el
   repo es grande, invoca antes a `scout` y pásale su mapa al planner.
   - `LISTO: no` → muestra las preguntas y detente. Una persona responde.
   - `RIESGO: alto` → cambia al carril profundo desde su paso 2.
   - En otro caso continúa sin gate: el plan queda en el PR.
2. **Implementación.** Crea la rama `feature/<id>`. Por cada subtask, en orden,
   invoca `coder` con la ruta del plan y el número de subtask. Las subtasks
   marcadas `difícil` se invocan con `model: opus`.
   - `bloqueada` → un reintento pasándole el error textual; si sigue, detente y reporta.
3. **Verificación.** Invoca `verifier` para correr `.agentflow/verify.sh <base>`
   completo. Si falla, pasa los fallos textuales a `coder` y verifica otra vez (máximo 2 vueltas).
4. **Revisión.** Invoca `reviewer` con la ruta del plan y la base. Con
   `VEREDICTO: cambios`, pasa los bloqueantes a `coder`, vuelve a verificar y
   revisa otra vez (máximo 2 vueltas). Los menores se anotan en el PR.
5. **Escáneres.** Invoca `verifier` para correr `.agentflow/scan.sh <base>`. Un
   hallazgo alto o crítico vuelve al `coder` una vez; si persiste, detente.
6. PR en borrador (paso final).

## Carril profundo
1. **Plan con el modelo más capaz.** Invoca `scout` si hace falta ubicar código, y
   luego `planner` con `model: opus`.
2. **Gate de diseño.** Muestra la decisión, las subtasks y el riesgo (léelos del
   plan) y **espera aprobación explícita**. Si piden cambios, vuelve al planner con el comentario.
3. **Implementación, verificación y revisión** como en el carril estándar, con dos
   diferencias: `reviewer` se invoca con `model: opus`, y las subtasks `difícil` también.
4. **Seguridad.** Invoca `guardian` con `model: opus` y la base. Con
   `VEREDICTO: falla`, los hallazgos vuelven al `coder`, se verifica y se revisa la
   seguridad otra vez (máximo 2 vueltas). Si sigue en `falla`, detente: seguridad
   nunca se aprueba por agotar intentos.
5. PR en borrador (paso final).

## Paso final: PR en borrador
`git push -u origin feature/<id>` y `gh pr create --draft` con: qué se hizo, el
carril usado, el resultado de la verificación, los veredictos de revisión y
seguridad, los hallazgos menores pendientes y lo que quedó fuera de alcance.
**El merge lo hace una persona.** Cierra con máximo 6 líneas y la URL del PR.

## Cuándo detenerte
Detente y reporta, sin insistir, cuando: el plan no está listo, un loop agotó sus
vueltas, el guardian sigue en `falla`, o falta una herramienta que impide
verificar. Di exactamente qué falló y qué necesitas para continuar.
