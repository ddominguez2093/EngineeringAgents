# Matriz de capacidades y dependencias — iOS(VIPER) → Flutter (iOS/Android/macOS/Web)

> El entregable #1 de la migración. El Librarian la pre-llena escaneando `legacy/`;
> **tú validas la columna Web** — sus gaps son decisiones de negocio, no técnicas.
> Leyenda: ✅ soportado · ⚠️ parcial / requiere trabajo · ❌ sin equivalente (gap).

| Capacidad iOS | Módulos VIPER que la usan | Plugin/enfoque Flutter | iOS | Android | macOS | Web | Veredicto / decisión |
|---|---|---|:--:|:--:|:--:|:--:|---|
| Keychain (tokens/credenciales) | Auth | flutter_secure_storage (web: httpOnly cookie / in-memory) | ✅ | ✅ | ✅ | ⚠️ | Web no es enclave seguro → tokens vía cookie httpOnly o memoria |
| Biometría (FaceID/TouchID) | Auth | local_auth | ✅ | ✅ | ⚠️ | ❌ | Fallback web: password/OTP |
| In-App Purchase (StoreKit) | Paywall | in_app_purchase | ✅ | ✅ | ⚠️ | ❌ | Web: flujo de pago distinto (checkout web) o excluir de web |
| Push notifications (APNs) | Notificaciones | firebase_messaging | ✅ | ✅ | ⚠️ | ⚠️ | Web push = FCM + service worker |
| Deep / Universal Links | Router | go_router + app_links | ✅ | ✅ | ✅ | ✅ | Config por plataforma + hosting web |
| Cámara / galería | (llenar) | camera / image_picker | ✅ | ✅ | ⚠️ | ⚠️ | Verificar soporte web del plugin |
| Archivos / documentos | (llenar) | file_picker / path_provider | ✅ | ✅ | ✅ | ⚠️ | `dart:io` no existe en web → abstraer |
| Ubicación / mapas | (llenar) | geolocator / google_maps_flutter | ✅ | ✅ | ⚠️ | ⚠️ | Revisar plugin por target |
| Analytics / crash | (llenar) | firebase_* / sentry | ✅ | ✅ | ⚠️ | ✅ | — |
| (agregar filas por cada dependencia nativa/3rd-party del proyecto) | | | | | | | |

## Cómo se llena

1. El Librarian lista cada `import`, framework nativo y dependencia (Podfile/SPM) de cada módulo VIPER en `legacy/`.
2. Propone el plugin Flutter candidato y su soporte por plataforma (verificado en pub.dev, no supuesto).
3. Marca ⚠️/❌ donde web o macOS no lleguen.
4. **Tú decides** qué hacer con cada gap de web: implementar alternativa, degradar la función en web, o excluirla del alcance de "paridad web".

## Gaps que casi siempre aparecen (revísalos explícitamente)

- Pagos in-app (StoreKit) en web/macOS.
- Biometría en web.
- Storage "seguro" en web.
- Tamaño de carga inicial de Flutter web (CanvasKit).
- SEO en páginas que lo necesiten.
