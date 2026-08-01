---
description: Version economica del flujo para tickets pequenos o de bajo riesgo - 3 etapas en vez de 7 agentes, sin sacrificar el escaneo de seguridad ni el merge humano.
argument-hint: <TICKET-ID o descripcion breve de la tarea>
---

Flujo LIGERO para **$ARGUMENTS**. Usa esto para tickets pequenos, bugs acotados o
cambios de bajo riesgo. Si al analizar detectas que el cambio toca auth, pagos,
datos de pacientes/PII o migraciones de datos, DETENTE y recomienda el `/eng-flow`
completo — esos siempre van por el camino largo.

## 1. Entender + plan corto (tu mismo, sin subagentes)

Lee el ticket (o la descripcion). Escribe un mini-plan de 5-10 lineas: que se va a
tocar, criterios de aceptacion, y riesgo (low/medium/high). Si el riesgo NO es low,
para aqui y sugiere `/eng-flow $ARGUMENTS`. Muestra el plan y pide OK del humano.

## 2. Implementar + probar (subagente coder, una sola delegacion)

Delega al subagente `coder` la implementacion EN UNA RAMA feature/, incluyendo que
el mismo escriba las pruebas y las corra (en el flujo lite el coder hace tambien de
tester). Pasale SOLO el mini-plan, no historial. Pide de vuelta un resumen corto:
archivos tocados, resultado real de las pruebas, y que dejo fuera.

Si las pruebas fallan, UNA iteracion de arreglo. Si sigue fallando, escala al humano.

## 3. Guardian (no se salta ni en lite)

Delega al subagente `guardian` el escaneo del cambio (corre los escaneres sobre la
rama y revisa `git diff` el mismo). Seguridad no se recorta: si hay hallazgo de
severidad alta, una iteracion de remediacion con el coder; si persiste, escala.

## 4. Cierre

Con guardian en `pass`: crea el draft PR (`gh pr create --draft`) y presentalo.
**El merge lo hace el humano.** Reporta en 5 lineas: que se hizo, pruebas, veredicto
de seguridad, URL del PR.

Disciplina de tokens: mensajes cortos entre etapas, YAML conciso, diffs en git.
