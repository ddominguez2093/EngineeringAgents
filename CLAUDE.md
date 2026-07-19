# CLAUDE.md — contexto que TODOS los agentes cargan

> Cargado por el SDK via `settingSources: ['project']`. Es el punto de entrada al
> "cerebro del proyecto"; el detalle vive en `.agentflow/context/` (lo genera el
> Librarian con `agentflow scan`).

## Qué es este proyecto

Migración de una app iOS (arquitectura **VIPER**) a **Flutter**, desplegable en
**iOS, Android, macOS y Web**. Web es **crítica con paridad total**. UI **adaptive
por plataforma** (Cupertino en iOS, Material en Android, escritorio en macOS/web).

## Reglas para los agentes

- El código fuente iOS vive en `legacy/` (read-only): es la **spec de paridad**.
  Primero se migra la lógica (Interactor/Presenter → UseCase/Notifier) conservando
  el comportamiento; luego se rehace la UI adaptive.
- "Done" = **paridad**, no solo pruebas verdes (ver `docs/MIGRATION_PLAYBOOK.md` §4).
- Antes de agregar una dependencia, revisa `docs/CAPABILITY_MATRIX.md`: verifica
  soporte en las 4 plataformas (sobre todo Web) o marca el gap.
- Nada de `dart:io` en código compartido con Web (usa imports condicionales).
- Secretos: nunca en el código ni en el bundle web. En Web los tokens no van en
  `flutter_secure_storage` (no es enclave) → cookie httpOnly o memoria.

## Convenciones técnicas (del ADR de programa)

- Estado: Riverpod · Routing: go_router (URLs para Web) · Modelos: freezed +
  json_serializable · Red: dio · UI adaptive detrás de una capa de abstracción.
- Comandos: `flutter analyze`, `flutter test`, builds por plataforma (ver CI).

> Detalle completo de arquitectura, patrones, UI/UX y glosario: `.agentflow/context/`.
