---
name: swift-ios
description: Experto en Swift/iOS para el Coder y el Tester. XCTest, SwiftPM, arquitecturas VIPER/MVVM, concurrencia estructurada y gotchas de seguridad en iOS.
---

# Skill: Swift / iOS

## Build & test
- Build: `xcodebuild -scheme <Scheme> build` o SwiftPM (`swift build`).
- Test: XCTest (`xcodebuild test` / `swift test`). Snapshot tests para UI cuando aplique.
- Lint/format: SwiftLint + swift-format.

## Convenciones
- Nombres segun las API Design Guidelines de Swift (claridad en el punto de uso).
- `struct`/`enum` sobre `class` salvo que se necesite identidad/herencia.
- Opcionales: evita `!`; usa `guard let` / `if let` y `??`.
- Concurrencia: `async/await` y actors; evita callbacks anidados y data races.

## Arquitectura
- Respeta la arquitectura del proyecto (VIPER o MVVM). Si es VIPER: separa
  View / Interactor / Presenter / Entity / Router y no filtres UIKit al Interactor.
- (El proyecto ya cuenta con un skill `swift-viper-reviewer` que puede reusar el
  Architect Reviewer para auditar cumplimiento VIPER.)

## Pruebas
- XCTest con nombres `test_shouldX_whenY`. Inyecta dependencias para poder mockear.
- Cubre Presenter/Interactor (logica) mas que la View.

## Seguridad
- Secretos en Keychain, nunca en UserDefaults ni hardcodeados.
- App Transport Security: HTTPS; valida certificados si haces pinning.
- Cuidado con deep links / URL schemes sin validar (entrada no confiable).
