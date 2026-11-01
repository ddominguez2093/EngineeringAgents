---
description: Prepara un repo para el flujo. Instala los scripts de verificación en .agentflow/ y escribe un contexto corto del proyecto (stacks, comandos, arquitectura y convenciones) que leen los agentes.
argument-hint: "(sin argumentos)"
---

Prepara este repositorio para `/eng-flow`.

## 1. Scripts
`mkdir -p .agentflow/plans && cp "${CLAUDE_PLUGIN_ROOT}"/scripts/*.sh "${CLAUDE_PLUGIN_ROOT}"/security/semgrep-flutter.yml .agentflow/`

No sobrescribas `.agentflow/verify.conf` si ya existe. Agrega `.agentflow/logs/` al `.gitignore`.

## 2. Grafo de código
Corre `.agentflow/graph.sh --global --html` con timeout de 600000 ms (la primera construcción en modo completo puede tardar varios minutos; si se corta, vuelve a correrlo: retoma desde la caché). Construye
`graphify-out/graph.json` con el código y la documentación del repo (ADR, `docs/`,
`CLAUDE.md`), nombra las comunidades, lo agrega al grafo global y abre la vista. **Es obligatorio:** si termina con error, muestra su
salida (incluye cómo instalar graphify) y detente.

## 3. Inventario
Invoca al subagente `scout` (que usará el grafo si existe) una vez por cada proyecto del repo (una app React, un
módulo Android, un servicio Spring Boot…), en paralelo si son varios. Pídele: stack
y versiones, comandos reales de lint, pruebas y build, capas y carpetas, cómo se
maneja estado, red, errores e inyección de dependencias, dónde viven las pruebas y
con qué framework, y una ruta de ejemplo de cada patrón.

## 4. Comandos de verificación
Corre `.agentflow/verify.sh --list`. Si la autodetección no reconoce un proyecto o
el comando no es el correcto (siempre pasa con iOS, que necesita esquema y
destino), escribe `.agentflow/verify.conf` con una línea por paso:

```
# directorio :: comando
ios :: xcodebuild test -scheme MiApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

## 5. Contexto
Escribe `.agentflow/context.md` con máximo 120 líneas:

```
# Contexto del proyecto
## Proyectos y stacks        (ruta → stack y versión)
## Comandos                  (lint, pruebas, build por proyecto)
## Arquitectura              (capas, y qué puede depender de qué)
## Convenciones              (nombres, errores, estado, DI; con una ruta de ejemplo)
## Pruebas                   (framework, ubicación, estilo)
## Cuidado                   (zonas frágiles, código generado, lo que no se toca)
```

Solo hechos comprobados en el código, con rutas. No copies aquí lo que ya está en la
documentación del repo: el grafo la contiene y los agentes la consultan con `graphify query`. Nada que el modelo ya sepa del
stack: eso vive en los skills. Este archivo se lee en cada corrida, así que cada
línea de más se paga siempre.

Termina con un resumen de 5 líneas: stacks encontrados, nodos del grafo, qué verifica `verify.sh` y qué falta instalar.
