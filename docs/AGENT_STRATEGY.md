# Estrategia del flujo

## El problema que resuelve
La versión anterior corría siempre siete agentes en secuencia, todos con el mismo
modelo, compartiendo una sola sesión. Eso costaba de más en los cambios chicos y
no daba mejor código en los grandes. Esta versión parte de tres ideas.

## 1. El proceso depende del riesgo
Un cambio de texto no necesita plan, revisor ni auditor de seguridad; una migración
de datos sí. `/eng-flow` hace un triage y elige carril:

- **rápido** — la sesión principal hace el cambio. Un subagente cuesta más en
  arranque de lo que ahorra en una tarea de tres archivos.
- **estándar** — plan, implementación por subtasks, verificación, revisión, escáneres. Sin gate humano intermedio.
- **profundo** — igual, con aprobación humana del diseño, modelos más capaces en
  plan y revisión, y una revisión de seguridad dedicada.

Si un carril descubre que subestimó la tarea, sube al siguiente. Nunca baja solo.

## 2. El modelo depende del razonamiento que pide la etapa
| Tipo de trabajo | Modelo | Por qué |
|---|---|---|
| Buscar, leer, correr herramientas, resumir salidas | haiku | Es mecánico y es donde más tokens se leen. |
| Implementar, probar, revisar un cambio normal | sonnet | La mejor relación entre calidad de código y costo. |
| Diseñar o juzgar un cambio de riesgo alto; subtasks difíciles | opus | Un error aquí se paga en todo lo que sigue. |

Cada agente declara su modelo por defecto y el comando lo sube a opus en el carril
profundo. Gastar opus en correr pruebas no mejora nada; ahorrarlo en el diseño de
una migración sale caro.

## 3. Lo que una herramienta puede decidir no lo decide un modelo
Lint, tipos, pruebas, build y escáneres los corre un script (`verify.sh`, `scan.sh`)
que imprime una línea por paso y solo en los fallos agrega la cola del log. El
modelo ve los errores, no miles de líneas de salida limpia. Un paso omitido o un
escáner ausente se reporta como incompleto; nunca cuenta como aprobado.

## Reglas de contexto
- **Cada subagente arranca limpio.** No hereda la conversación: recibe la ruta del plan, la subtask y la base.
- **Se pasan rutas, no contenido.** El plan vive en `.agentflow/plans/<id>.md` y el
  código en git. Nada se recorta ni se copia de mensaje en mensaje.
- **Respuestas con tope de líneas** y formato fijo, con el veredicto en la primera línea.
- **Los skills se cargan por stack.** Solo su descripción está siempre en contexto;
  el cuerpo se carga cuando el agente va a tocar ese tipo de archivo.
- **`context.md` es corto** (máximo 120 líneas) y solo tiene hechos del proyecto.

## Qué sube la calidad del código
- **El plan es el contrato.** Cada subtask dice qué archivos toca, qué debe cumplir
  y qué pruebas lo demuestran. El coder no adivina y el revisor tiene contra qué comparar.
- **Las pruebas se escriben con el código**, por quien entiende el cambio, y la
  verificación corre antes de entregar cada subtask.
- **Se implementan todas las subtasks**, una por invocación, cada una con contexto limpio.
- **La revisión es independiente** y solo bloquea con una falla concreta y reproducible.
- **Los skills son listas de control por stack**: los errores que de verdad aparecen
  en React, Flutter, Swift, Compose y Spring, no convenciones genéricas.
- **Los huecos de negocio detienen el flujo.** El planner no inventa reglas: pregunta.

## Loops y cuándo se detiene
| Loop | Máximo | Al agotarse |
|---|---|---|
| Verificación → coder | 2 | Se detiene y reporta el error |
| Revisión → coder | 2 | Se detiene y reporta los bloqueantes |
| Seguridad → coder | 2 | Se detiene; seguridad nunca se aprueba por agotamiento |

## Guardrails del propio sistema
- Mínimo privilegio: `scout`, `reviewer` y `guardian` no editan; `verifier` solo ejecuta.
- El hook `PreToolUse` bloquea `rm` recursivo sobre la raíz o el home, descarga y
  ejecución directa, force-push a ramas principales y el acceso a archivos de secretos.
- El trabajo va en `feature/<id>` y termina en un PR en borrador. El merge es humano.

## Extender
Un stack nuevo es una carpeta en `skills/` con su `SKILL.md`, una línea en la lista
de skills de `coder` y `reviewer`, y un caso en `detect()` de `verify.sh`.
