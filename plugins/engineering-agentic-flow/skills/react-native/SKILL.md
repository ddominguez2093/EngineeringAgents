---
name: react-native
description: Experto en React Native para el Coder y el Tester. Jest + React Native Testing Library, Metro, modulos nativos y seguridad movil.
---

# Skill: React Native

## Build & test
- Test: `jest` con React Native Testing Library; Detox para e2e cuando aplique.
- Lint/format: ESLint + Prettier; `tsc --noEmit` si es TypeScript (preferir TS).

## Convenciones
- Componentes funcionales + hooks; memoiza con cuidado (`useMemo`/`useCallback`) solo donde importe.
- Estado segun el proyecto (Redux Toolkit / Zustand / Context): no mezcles.
- Navegacion con React Navigation; tipa las rutas si es TS.
- Separa logica de negocio de la UI (hooks/servicios).

## Pruebas
- Testea comportamiento, no implementacion (queries por rol/texto). Mockea modulos nativos.

## Seguridad (alinear con Guardian)
- Secretos fuera del bundle; react-native-keychain para credenciales.
- Valida deep links y props de navegacion (entrada no confiable).
- HTTPS; cuidado con `WebView` (deshabilita JS si no se necesita) y con `eval`.
- Revisa dependencias npm (`npm audit`) — superficie tipica de vulnerabilidades.
