---
name: swift-ios
description: Guía de Swift para iOS (SwiftUI, UIKit, VIPER o MVVM, concurrencia). Cárgala antes de escribir o revisar archivos .swift.
---

# Swift / iOS

Primero el proyecto: respeta su arquitectura (VIPER, MVVM, TCA), su versión mínima
de iOS y su versión de Swift. No introduzcas SwiftUI en un módulo UIKit ni al revés
sin que el plan lo pida.

## Comandos
- El comando real con esquema y destino vive en `.agentflow/verify.conf`. Usa
  `xcodebuild … -quiet` para que la salida sean solo errores.
- SwiftPM: `swift build`, `swift test`. Lint: SwiftLint si el proyecto lo tiene.
- No edites `project.pbxproj` a mano salvo para registrar archivos nuevos; si el
  proyecto usa XcodeGen o Tuist, edita el manifiesto y regenera.

## Arquitectura
- **VIPER**: la View solo pinta y reenvía eventos; el Presenter formatea y decide;
  el Interactor tiene la lógica de negocio y no importa UIKit; el Router navega;
  las Entities son datos. Las dependencias entran por protocolo e inicializador.
  Las referencias hacia atrás (Presenter → View, Interactor → Presenter) son `weak`.
- **MVVM / SwiftUI**: la vista no tiene lógica; el view model es `@MainActor`.
  `@Observable` si el mínimo es iOS 17, `ObservableObject` si es menor: sigue lo que ya usa el proyecto.
- `struct` y `enum` por defecto; `class` solo si hace falta identidad o herencia. `final` en las clases.

## Concurrencia
- `async/await` y `Task`; no agregues completion handlers nuevos.
- Todo lo que toca UI corre en `@MainActor`. No uses `DispatchQueue.main.async` para parchar un aviso del compilador.
- Con concurrencia estricta, los tipos que cruzan actores son `Sendable`. No
  silencies con `@unchecked Sendable` ni `nonisolated(unsafe)` sin una razón escrita.
- Guarda el `Task` que lanzas y cancélalo cuando la pantalla desaparece; revisa
  `Task.isCancelled` o usa `try Task.checkCancellation()` en trabajos largos.
- En SwiftUI, la carga inicial va en `.task { }`, que se cancela sola.

## Errores frecuentes (lista de control para revisar)
- Ciclos de retención: closures guardados que capturan `self` fuerte, delegados no `weak`, `Timer` y observadores sin invalidar.
- `!`, `try!` y `as!` sobre datos que pueden faltar. Usa `guard let` y un error con significado.
- Actualizar UI fuera del hilo principal.
- Estado de SwiftUI mal ubicado: `@StateObject` para lo que la vista crea,
  `@ObservedObject` para lo que recibe; con `@Observable`, `@State` para lo que crea.
- `catch` vacío o `try?` que se traga un error que el usuario debía ver.
- Trabajo pesado o síncrono de red y disco en el hilo principal.
- `Codable` que falla entero por un campo opcional que el backend omite.
- Textos visibles sin localizar; vistas sin `accessibilityLabel` en controles de solo icono; fuentes fijas que ignoran Dynamic Type.

## Pruebas
- Usa el framework del proyecto: XCTest, o Swift Testing (`@Test`, `#expect`) si ya está adoptado.
- Prueba Presenter, Interactor y view models con dobles inyectados por protocolo. La vista se prueba poco.
- Pruebas `async` reales, sin `sleep`. Para código con tiempo, inyecta el reloj.
- Cubre el camino de error y el estado vacío, no solo el feliz.

## Seguridad
- Tokens y credenciales en Keychain, con la clase de accesibilidad más restrictiva
  que funcione. Nunca en `UserDefaults`, plist o código.
- No relajes App Transport Security. Si hay pinning, no lo desactives en release.
- Deep links, universal links y push payloads son entrada no confiable: valida antes de navegar o ejecutar.
- No registres tokens ni datos personales con `print` u `os_log` público.
