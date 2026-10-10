---
name: android-compose
description: Guía de Android con Kotlin y Jetpack Compose. Cárgala antes de escribir o revisar archivos .kt de un módulo Android (composables, ViewModel, corrutinas, Flow, Hilt, Room, pruebas).
---

# Android (Kotlin + Jetpack Compose)

Primero el proyecto: respeta su arquitectura (capas UI / dominio / datos), su
inyección de dependencias (Hilt, Koin), su navegación y su catálogo de versiones
(`gradle/libs.versions.toml`). Las dependencias nuevas se declaran en el catálogo.

## Comandos
- `./gradlew lintDebug testDebugUnitTest` y `assembleDebug`. Pruebas instrumentadas:
  `connectedDebugAndroidTest` (necesitan emulador; no las corras sin que se pida).
- Formato y análisis: ktlint o detekt si el proyecto los tiene.

## Compose
- **Estado arriba, eventos abajo.** Un composable de pantalla recibe el `UiState` y
  lambdas; no recibe el `ViewModel` salvo en la raíz de la ruta. Así se puede previsualizar y probar.
- `remember` para lo que sobrevive a recomposición, `rememberSaveable` para lo que
  debe sobrevivir a rotación y muerte de proceso (texto de un campo, selección).
- Observa flujos con `collectAsStateWithLifecycle()`, no con `collectAsState()`.
- Efectos: `LaunchedEffect(clave)` con la clave correcta; `rememberCoroutineScope`
  para lanzar desde un evento; `DisposableEffect` cuando hay que limpiar. Nunca
  lances corrutinas ni cambies estado directamente en el cuerpo del composable.
- Todo composable reutilizable acepta `modifier: Modifier = Modifier` como primer
  parámetro opcional y lo aplica a su raíz.
- Listas con `LazyColumn` y `key` estable por elemento.
- Colores, tipografía y espaciado salen del tema (`MaterialTheme`), no de valores sueltos.

## ViewModel, corrutinas y Flow
- Un `StateFlow<UiState>` inmutable por pantalla (data class o sealed interface con
  carga, contenido y error). Actualiza con `update { it.copy(…) }`.
- Los eventos de una sola vez (navegar, snackbar) se modelan como estado que la UI
  consume y confirma, no como un `SharedFlow` que se pierde en una rotación.
- `viewModelScope` para lanzar. Nunca `GlobalScope` ni `runBlocking` en código de la app.
- Las funciones `suspend` son seguras para el hilo principal: quien hace E/S cambia
  de dispatcher con `withContext`, y los dispatchers se inyectan para poder probar.
- `stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), inicial)` para exponer flujos fríos.
- No atrapes `CancellationException`: si usas `catch (e: Exception)`, vuelve a lanzarla.

## Errores frecuentes (lista de control para revisar)
- Estado que se pierde al rotar por usar `remember` donde iba `rememberSaveable` o el ViewModel.
- `LaunchedEffect(Unit)` que debía depender de un parámetro, o un efecto que se relanza en cada recomposición.
- Pasar a un composable listas mutables, lambdas inestables o el ViewModel completo: recomposiciones de más.
- Guardar `Context`, `Activity` o una `View` en el ViewModel (fuga de memoria).
- E/S en el hilo principal; `collect` en la UI fuera de un scope ligado al ciclo de vida.
- `!!` sobre datos que pueden faltar; `lateinit` leído antes de inicializar.
- Consultas de Room que devuelven todo cuando se necesitaba paginar u observar con `Flow`.
- Controles de solo icono sin `contentDescription`; áreas táctiles menores a 48 dp; textos fijos en lugar de `stringResource`.

## Pruebas
- Unitarias con JUnit, corrutinas con `runTest` y un dispatcher de prueba inyectado
  (regla que reemplaza `Dispatchers.Main`). Flujos con Turbine.
- Dobles con fakes escritos a mano o MockK, según el proyecto.
- UI con `createComposeRule()`, buscando por texto, `contentDescription` o `testTag`.
- Cubre carga, error y vacío, y lo que pasa al recrear (estado restaurado).

## Seguridad
- Secretos fuera del repositorio y del APK: una llave en `BuildConfig` o `strings.xml` se extrae en minutos.
- Tokens con Keystore (DataStore o SharedPreferences cifrados), nunca en preferencias planas ni en logs.
- `android:exported="false"` en todo componente que no deba recibir intents externos.
  Los extras de un intent y los deep links son entrada no confiable.
- Sin tráfico en claro (`usesCleartextTraffic`), y `WebView` con JavaScript solo para orígenes propios.
- `PendingIntent` con `FLAG_IMMUTABLE` salvo que haga falta lo contrario.
