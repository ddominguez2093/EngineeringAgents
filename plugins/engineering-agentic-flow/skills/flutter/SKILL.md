---
name: flutter
description: Guía de Flutter y Dart. Cárgala antes de escribir o revisar archivos .dart (widgets, estado, navegación, red, pruebas) en apps móviles, web o de escritorio.
---

# Flutter / Dart

Primero el proyecto: usa su gestor de estado (Riverpod, Bloc, Provider), su router y
su cliente de red. No mezcles dos enfoques de estado en la misma feature.

## Comandos
- `flutter analyze` y `flutter test`; `dart format .` antes de entregar.
- Si hay código generado (freezed, json_serializable, riverpod_generator):
  `dart run build_runner build --delete-conflicting-outputs`. No edites `*.g.dart` ni `*.freezed.dart`.

## Widgets
- `build` es puro y barato: sin peticiones, sin crear controladores, sin efectos.
- Widgets pequeños como **clases**, no métodos `_buildAlgo()`: las clases permiten `const` y reconstruyen menos.
- `const` en todo constructor que lo admita.
- Listas largas con `ListView.builder` (o slivers), nunca `Column` dentro de un scroll con cientos de hijos.
- Todo lo que se crea se libera: `TextEditingController`, `AnimationController`,
  `FocusNode`, `StreamSubscription`, `Timer` se cierran en `dispose`.

## Estado y asincronía
- La lógica vive fuera de los widgets (notifier, bloc, use case). El widget observa y despacha.
- El estado es inmutable (freezed o `copyWith`) y modela carga, dato y error de
  forma explícita (`AsyncValue`, estados sellados), no con tres booleanos.
- **Después de un `await`, comprueba `context.mounted`** (o `mounted` en un `State`)
  antes de usar `context`, navegar o llamar a `setState`.
- Todo `Future` se espera o se maneja; captura errores en la frontera (repositorio)
  y conviértelos al tipo de error del proyecto.

## Errores frecuentes (lista de control para revisar)
- Usar `BuildContext` tras un `await` sin comprobar `mounted`.
- `ref.read` dentro de `build` cuando debía ser `ref.watch`, o `ref.watch` dentro de un callback.
- Crear un `Future` o `Stream` dentro de `build` y pasarlo a `FutureBuilder`/`StreamBuilder`: se reinicia en cada rebuild.
- Controladores o suscripciones sin `dispose`.
- `setState` que reconstruye una pantalla entera por un cambio pequeño.
- Tamaños fijos en píxeles que rompen en pantallas chicas, con texto grande o en web; `Expanded`/`Flexible` faltantes que causan overflow.
- `!` sobre un nullable que sí puede ser nulo.
- `dart:io` (`File`, `Platform`) en código que también compila a web: usa imports condicionales o `kIsWeb`.

## Multiplataforma
- Antes de agregar un paquete, confirma que soporta todas las plataformas del proyecto.
- UI adaptable: respeta `SafeArea`, el escalado de texto del sistema y los anchos
  de tablet y web con `LayoutBuilder` o breakpoints del proyecto.
- En web, las rutas son URLs: navegación declarativa (go_router) y estado que sobreviva a recargar.

## Pruebas
- Unitarias sobre notifiers, blocs y use cases con dependencias falsas (mocktail).
- De widget con `pumpWidget`, buscando por texto, semántica o `Key`; `pumpAndSettle`
  solo cuando hay animaciones que terminan. Envuelve en los providers y el `MaterialApp` que el widget necesita.
- Golden solo para componentes visuales estables. Cubre carga, error y vacío.

## Seguridad
- Secretos fuera del código y de `assets/`. Lo que va por `--dart-define` queda en el binario: no es un secreto.
- Tokens en `flutter_secure_storage` en móvil. En web eso no es un enclave: cookie `httpOnly` o memoria.
- Valida deep links y parámetros de ruta como entrada no confiable. `WebView` con
  JavaScript solo para orígenes propios. No registres tokens ni datos personales en logs.
