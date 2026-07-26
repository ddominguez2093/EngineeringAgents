---
name: flutter-dart
description: Experto en Flutter/Dart para el Coder y el Tester. flutter test, widget/golden tests, gestion de estado y seguridad.
---

# Skill: Flutter / Dart

## Build & test
- Build: `flutter build <target>`. Test: `flutter test` (unit + widget); golden tests para UI.
- Lint/format: `dart format`, `flutter analyze` (lints en `analysis_options.yaml`).

## Convenciones
- Null-safety siempre; `final`/`const` agresivo (const constructors reducen rebuilds).
- Widgets pequenos y componibles; separa presentacion de logica.
- Gestion de estado segun el proyecto (Riverpod/Bloc/Provider): no mezcles enfoques.
- `async`/`await`; maneja errores de Future y estados de carga/error en la UI.

## Pruebas
- Unit sobre logica/notifiers; widget tests con `pumpWidget` y `find`. Mockea servicios (mocktail).

## Seguridad (alinear con Guardian)
- Secretos vía `--dart-define`/flutter_secure_storage, nunca en el codigo ni en assets.
- Valida input; cuidado con `WebView` y deep links no confiables.
- Revisa dependencias `pub` por vulnerabilidades conocidas.
