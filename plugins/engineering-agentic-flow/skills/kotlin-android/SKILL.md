---
name: kotlin-android
description: Experto en Kotlin/Android para el Coder y el Tester. JUnit+Espresso, Gradle, Jetpack Compose, lifecycle y seguridad Android.
---

# Skill: Kotlin / Android

## Build & test
- Build: `./gradlew assembleDebug`. Test: `./gradlew test` (JUnit) y `connectedAndroidTest` (Espresso).
- Lint/format: ktlint / detekt, Android Lint.

## Convenciones
- Idiomatico Kotlin: `val` sobre `var`, data classes, `sealed`/`when` exhaustivo, null-safety (`?`, `?:`, evita `!!`).
- Coroutines + Flow para async; respeta el lifecycle (`viewModelScope`, `repeatOnLifecycle`).
- Jetpack: ViewModel/StateFlow, Navigation, Hilt para DI. Compose sobre XML en features nuevas si el proyecto ya lo usa.

## Pruebas
- Unit sobre ViewModel/UseCase (JUnit + MockK + Turbine para Flows). UI con Espresso/Compose testing.

## Seguridad (alinear con Guardian)
- Secretos fuera del APK; usa EncryptedSharedPreferences / Keystore.
- Valida Intents y deep links (entrada no confiable). Permisos minimos.
- HTTPS + certificate pinning donde aplique; no loguees PII.
