# Playbook — Migración iOS (VIPER) → Flutter multiplataforma

> Contexto de este proyecto: app iOS en **VIPER** → **Flutter** para **iOS, Android, macOS y Web**. Web es **crítica con paridad total**. UI **adaptive por plataforma**. Las **épicas de migración ya existen** (tú las manejas), así que el flujo de agentes las *consume*; no te impone el troceo.

Este playbook adapta `AGENT_STRATEGY.md` al caso concreto de una migración. La diferencia clave frente a "feature nueva" es que **el oráculo de correctitud ya existe: es la app iOS**. Por eso el eje de todo es la *paridad*, y por eso hay una Fase 0 antes de soltar a los agentes screen por screen.

---

## 0. La única cosa que no debes saltarte

**La matriz de capacidades y dependencias, hecha ANTES de escribir código.** Es donde estas migraciones se atoran, y con web-paridad-total el riesgo es máximo: no toda capacidad nativa de iOS tiene un plugin de Flutter que soporte *además* web y macOS.

Para cada módulo VIPER, inventaría sus dependencias nativas y de terceros, y mapéalas a: (a) un plugin de Flutter que soporte los 4 targets, (b) un *platform channel* que tú implementas, o (c) un **gap real** sin equivalente. Ejemplo de plantilla (`docs/CAPABILITY_MATRIX.md`):

| Capacidad iOS | Módulos que la usan | Plugin Flutter candidato | iOS | Android | macOS | **Web** | Veredicto |
|---|---|---|:--:|:--:|:--:|:--:|---|
| Keychain (tokens) | Auth | flutter_secure_storage | ✅ | ✅ | ✅ | ⚠️ | Web NO es "secure" (ver §6) |
| Biometría (FaceID) | Auth | local_auth | ✅ | ✅ | ⚠️ | ❌ | Gap en web → fallback |
| In-App Purchase / StoreKit | Paywall | in_app_purchase | ✅ | ✅ | ⚠️ | ❌ | **Gap: no hay IAP en web** → flujo de pago web distinto |
| Push (APNs) | Notif | firebase_messaging | ✅ | ✅ | ⚠️ | ⚠️ | Web push = FCM + service worker |
| Cámara / archivos | … | camera / file_picker | ✅ | ✅ | ⚠️ | ⚠️ | Verificar soporte web por plugin |
| Deep / Universal Links | Router | app_links / go_router | ✅ | ✅ | ✅ | ✅ | Config por plataforma |

**Los gaps de la columna Web son decisiones de negocio, no técnicas.** Si el paywall usa StoreKit, "paridad total en web" para esa pantalla es imposible tal cual — necesitas un flujo de pago web (Stripe/checkout) o excluir esa función de web. Descubre esto en la semana 1, no en la 20.

---

## 1. Cómo encaja tu migración en el flujo de agentes

Como ya tienes épicas, el pipeline se alimenta de ellas así:

```
Tu Épica ─► [Analyst] refina cada ticket de migración extrayendo los criterios de
             aceptación DEL MÓDULO VIPER original (con swift-viper-reviewer)
          ─► [Architect] diseña la implementación Flutter respetando el ADR de programa
          ─► ⟦Gate A⟧
          ─► (Coder ⇄ Tester)  Coder LEE Swift/VIPER y ESCRIBE Dart adaptive;
             Tester escribe el ARNÉS DE PARIDAD (ver §4) y lo corre en las 4 plataformas
          ─► [Architect Reviewer] verifica cumplimiento adaptive + mapeo VIPER
          ─► [Guardian] seguridad, con foco en storage web y superficie web
          ─► ⟦Gate B: merge humano⟧
```

Cambios respecto al flujo genérico:

- **Doble contexto.** El Coder trabaja en el repo Flutter *destino* pero necesita leer el repo iOS *fuente* como referencia read-only. Recomendación: monta el código Swift en `legacy/` dentro del workspace (o como carpeta hermana), y el Librarian lo indexa como spec, no como código a compilar.
- **El Analyst extrae, no inventa.** En VIPER, el `Interactor` y el `Presenter` *son* la especificación de comportamiento. El Analyst (usando `swift-viper-reviewer`) los lee y produce los criterios de aceptación de paridad. Los gaps que escala al humano ahora incluyen "esta capacidad no existe en web".
- **"Done" = paridad, no solo pruebas verdes.** El Tester no valida "funciona"; valida "se comporta igual que el módulo iOS" (§4).

---

## 2. Fase 0 — antes de tocar las épicas (1–2 semanas)

Aunque ya tengas el troceo, **no arranques por las épicas de negocio**. Haz primero esto, en orden:

**2.1. Matriz de capacidades (§0).** El entregable #1. El Librarian la genera escaneando `legacy/`; tú validas los veredictos de la columna Web.

**2.2. Walking skeleton en las 4 plataformas.** Migra UN módulo VIPER simple end-to-end (idealmente Auth/login + una pantalla con una llamada de red) y **despliégalo a iOS, Android, macOS y web**. El objetivo no es la feature: es probar el toolchain completo y que los plugins elegidos de verdad corren en web y macOS. Si algo va a explotar (un plugin sin web, CORS del API, tamaño de carga), que explote aquí con 1 pantalla, no con 50.

**2.3. ADR de programa (decisiones grandes, UNA vez, con Gate A humano).** El Architect lo produce; tú lo apruebas. Mis recomendaciones concretas para tu caso:

| Decisión | Recomendación | Por qué en tu caso |
|---|---|---|
| Gestión de estado | **Riverpod** | Testeable, agnóstico de plataforma, mapea limpio al `Presenter` de VIPER. (Bloc es válido si tu equipo ya lo domina.) |
| Estructura de proyecto | **Feature-first**, un folder por módulo espejando VIPER | Facilita migrar módulo por módulo y medir avance |
| Navegación / routing | **go_router** | Web-paridad-total *exige* rutas por URL; go_router lo da y unifica deep links en las 4 plataformas |
| UI adaptive | Capa de abstracción propia (Cupertino en iOS, Material en Android, desktop en macOS/web) + `flutter_adaptive_scaffold` para navegación (bottom bar móvil ↔ rail/sidebar desktop/web) | Tu decisión de "adaptive por plataforma" |
| Modelos / serialización | **freezed + json_serializable** | Inmutabilidad y `copyWith`; equivale a tus `Entity` |
| Red | **dio** (+ interceptores) | Timeouts, reintentos, y manejo de CORS/headers para web |
| DI | Providers de Riverpod (o get_it + injectable) | Reemplaza el wiring del `Router`/ensamblado VIPER |
| Storage seguro | Por plataforma (ver §6) | En web NO es seguro; hay que decidir estrategia de tokens |
| Renderer web | **CanvasKit** (o WASM si tu versión lo permite) con carga diferida | Paridad visual; a cambio, presupuesto de carga inicial a vigilar |
| Versiones mínimas | Fíjalas por plataforma en el ADR | Evita sorpresas de plugins |

**2.4. CI multiplataforma desde el día 1.** Matriz que en cada PR corra `flutter analyze`, `flutter test` (con goldens), y un **build de humo por plataforma**: `build apk`, `build ios --no-codesign`, `build macos`, `build web`. Un cambio no está "verde" hasta que compila en las 4.

---

## 3. Mapeo VIPER → Flutter (referencia para Coder y Reviewer)

VIPER se traduce con una limpieza que juega a tu favor:

| VIPER (iOS) | Flutter (destino) | Nota |
|---|---|---|
| **View** (UIViewController) | Widget (adaptive) | Aquí vive la decisión Cupertino/Material/desktop |
| **Presenter** | Notifier/Controller (Riverpod) o Bloc | La lógica de presentación; es lo que el Tester valida a paridad |
| **Interactor** | UseCase / Service | Reglas de negocio; **oráculo de paridad principal** |
| **Entity** | Model (freezed) | Datos |
| **Router** | go_router + providers | Navegación + ensamblado de dependencias |

Regla para el Coder: **primero lee el Interactor y el Presenter del módulo (con swift-viper-reviewer) y reprodúcelos como UseCase + Notifier con la MISMA lógica**; recién entonces construye la View adaptive. La lógica se migra por comportamiento; la UI se rehace nativa por plataforma.

---

## 4. El arnés de paridad (la adaptación clave del flujo)

En una migración, "pruebas que pasan" no basta: pueden pasar y aun así comportarse distinto a iOS. Define **paridad** como la Definition of Done del Tester:

1. **Paridad de lógica.** Para cada UseCase/Notifier migrado: mismos inputs → mismas transiciones de estado/outputs que el `Interactor`/`Presenter` original. Si la app iOS tiene tests, tradúcelos como casos. Si no, el Analyst genera los casos leyendo el Interactor. Estos son tests unitarios en `flutter test`, agnósticos de plataforma.
2. **Paridad visual (golden tests) por plataforma.** Con `golden_toolkit`/`alchemist`, snapshots por plataforma (iOS/Android/desktop). Aquí "adaptive" se verifica: el golden de iOS luce Cupertino, el de Android Material, etc.
3. **Paridad de flujo (integration/e2e).** `integration_test` corriendo el flujo clave en cada target — incluida **web** (headless), que es donde aparecen los sustos.
4. **Checklist manual de paridad** para lo que no se automatiza (gestos, haptics, animaciones): el Reviewer lo adjunta al PR.

El Tester reporta paridad por dimensión; el pipeline no llega a Gate B si la paridad de lógica no está completa.

---

## 5. UI adaptive, en concreto

- **Navegación adaptive**: bottom navigation / tabs en móvil ↔ `NavigationRail`/sidebar en macOS y web (ventanas anchas). `flutter_adaptive_scaffold` o tu propia capa según breakpoints.
- **Componentes**: una fábrica que devuelve `Cupertino*` en iOS y `Material*` en el resto (botones, switches, diálogos, pull-to-refresh, date pickers). El Coder no debe esparcir `if (Platform.isIOS)` por toda la UI: eso va detrás de la abstracción.
- **Input**: en macOS/web hay teclado y mouse — hover states, atajos, foco, scroll con rueda. Es paridad *hacia arriba*: la app iOS no lo tenía, pero desktop/web lo esperan.
- **Golden tests por plataforma** son tu red para que "adaptive" no se degrade con el tiempo.

---

## 6. Web crítica: gotchas y gaps honestos

Como web es paridad-total, hay que ser explícito con lo que web *no* da gratis:

- **`dart:io` no existe en web.** Todo acceso a filesystem/sockets va detrás de imports condicionales o de una abstracción de plataforma. El Reviewer debe rechazar `dart:io` filtrado a código compartido.
- **Storage seguro en web NO es seguro.** `flutter_secure_storage` en web usa el almacenamiento del navegador (no un enclave). Para tokens en web lo correcto es **cookies httpOnly** emitidas por el backend o tokens en memoria (no persistidos). Es un cambio de arquitectura de auth respecto a iOS/Keychain — el Guardian debe marcarlo.
- **IAP/StoreKit no aplica en web/macOS-fuera-de-AppStore.** Si hay paywall, web necesita un flujo de pago distinto (checkout web). Decisión de negocio temprana.
- **Biometría (local_auth): sin equivalente en web.** Define el fallback (password/OTP).
- **Push en web**: FCM web + service worker; distinto a APNs. Config y permisos aparte.
- **Carga inicial (CanvasKit ~varios MB)**: presupuesto de tamaño, carga diferida de features, y medirlo en CI. Afecta la percepción de "paridad".
- **SEO**: Flutter web renderiza en canvas; si alguna página necesita SEO, es una limitación real — puede requerir tratamiento aparte para esas rutas.
- **CORS y deep links**: el API debe permitir el origen web; las universal links de iOS se replican con go_router + config de hosting.

El Guardian de este proyecto corre, además de lo estándar, foco en: secretos en el bundle web, `dart:io` filtrado, storage de tokens en web, y superficie de `WebView`/`eval`.

---

## 7. Ajustes concretos al scaffold (ya incluidos para este proyecto)

- `.agentflow/config.yaml`: `stacks: [flutter-dart, swift-ios]`, comandos `flutter test` / `flutter analyze` / builds por plataforma, y `gateARequiredFor: [low, medium, high]` al inicio (paridad importa en todo).
- **Coder** con `skills: [ponytail, flutter-dart, swift-ios]`: escribe Dart, lee Swift/VIPER.
- **Librarian** indexa `legacy/` (código iOS) → produce la matriz de capacidades + inventario de módulos VIPER + spec de paridad.
- **Tester** con la Definition of Done de paridad (§4) y corrida por plataforma, incluida web.
- **Reviewer** con `swift-viper-reviewer` para verificar que el mapeo VIPER→Flutter conserve la lógica, y con checks de adaptive y anti-`dart:io`.

---

## 8. Qué haría yo las primeras 2 semanas

1. Monta el repo Flutter + `legacy/` con el código iOS; corre `agentflow init` (el Librarian genera la matriz de capacidades y el inventario VIPER).
2. Tú revisas la **matriz de capacidades** y marcas los gaps de web (IAP, biometría, storage). Ahí decides el alcance real de "paridad web".
3. El Architect produce el **ADR de programa** (§2.3); Gate A humano.
4. Walking skeleton de 1 módulo (Auth) desplegado a las 4 plataformas + CI multiplataforma verde.
5. Recién entonces: suelta el pipeline sobre la primera épica, empezando por módulos VIPER de bajo riesgo para calibrar el arnés de paridad antes de tocar el paywall o auth complejo.

> Regla de oro: en una migración, la velocidad viene de un **arné de paridad confiable** y de haber matado los **gaps de plataforma** en la semana 1. Los agentes aceleran la parte mecánica (leer VIPER, escribir Dart, tests, seguridad); las decisiones de alcance de web son tuyas y van primero.
