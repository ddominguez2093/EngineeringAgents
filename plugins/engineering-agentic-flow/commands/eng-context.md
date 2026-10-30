---
description: Prepara un repo para el flujo. Instala los scripts de verificación en .agentflow/ y escribe un contexto corto del proyecto (stacks, comandos, arquitectura y convenciones) que leen los agentes.
argument-hint: "(sin argumentos)"
---

Prepara este repositorio para `/eng-flow`.

## 1. Scripts
`mkdir -p .agentflow/plans && cp "${CLAUDE_PLUGIN_ROOT}"/scripts/*.sh "${CLAUDE_PLUGIN_ROOT}"/security/semgrep-flutter.yml .agentflow/`

No sobrescribas `.agentflow/verify.conf` si ya existe. Agrega `.agentflow/logs/` al `.gitignore`.

## 2. Grafo de código
Corre `.agentflow/graph.sh --global`. Construye `graphify-out/graph.json` con el AST
del repo (local, sin LLM) y lo agrega al grafo global de todos tus repos. Si
graphify no está instalado, avisa en el resumen final (`uv tool install graphifyy`)
y continúa sin grafo.

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

Solo hechos comprobados en el código, con rutas. Nada que el modelo ya sepa del
stack: eso vive en los skills. Este archivo se lee en cada corrida, así que cada
línea de más se paga siempre.

Termina con un resumen de 5 líneas: stacks encontrados, nodos del grafo, qué verifica `verify.sh` y qué falta instalar.
