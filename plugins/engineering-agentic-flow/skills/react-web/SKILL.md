---
name: react-web
description: Guía de React web con TypeScript. Cárgala antes de escribir o revisar archivos .tsx, .jsx o .ts de una app React (componentes, hooks, estado, datos, pruebas).
---

# React web (TypeScript)

Primero el proyecto: usa su gestor de estado, su cliente de datos, su librería de
componentes y su estilo de pruebas. Lo de abajo aplica donde el proyecto no decide.

## Comandos
Lee los scripts de `package.json` y usa el gestor que indique el lockfile (npm, pnpm,
yarn). La verificación del flujo es `.agentflow/verify.sh` (typecheck, lint, test, build).

## Componentes y estado
- Componentes de función, props tipadas con `type` o `interface`, sin `any` ni
  `as` para callar al compilador. `unknown` y un guard si el dato viene de fuera.
- El estado vive lo más abajo posible. Si dos componentes lo comparten, súbelo al
  ancestro común antes de pensar en un store global.
- **No guardes en estado lo que se puede calcular** de props u otro estado: calcúlalo en el render.
- Datos del servidor van en el cliente de datos del proyecto (TanStack Query, RTK
  Query, SWR), no en `useState` + `useEffect`. Si no hay cliente, un hook propio con
  `AbortController` y estados de carga, error y vacío.
- Formularios: la librería del proyecto (React Hook Form, Formik). Valida con el
  mismo esquema (zod, yup) que tipa el dato.

## `useEffect`: el origen de casi todos los bugs
- Es para sincronizar con algo externo (suscripción, DOM, temporizador). No para
  derivar estado ni para reaccionar a un evento: eso va en el handler.
- Todo efecto con suscripción, temporizador o petición devuelve su limpieza.
- Dependencias completas. Si el linter se queja, el diseño está mal; no lo silencies.
- Peticiones dentro de un efecto: cancela o ignora la respuesta vieja, o habrá condiciones de carrera.

## Errores frecuentes (lista de control para revisar)
- `key` con el índice en listas que se reordenan, insertan o filtran.
- Mutar estado (`push`, `sort`, asignar a un objeto) en lugar de crear uno nuevo.
- Leer el estado justo después de `setState` esperando el valor nuevo; usa la forma `set(prev => …)`.
- Crear objetos, arrays o funciones nuevos en cada render como dependencia de un efecto o prop de un hijo memoizado.
- `useMemo`/`useCallback`/`memo` por reflejo: solo donde se midió un problema o para estabilizar una dependencia.
- Olvidar los estados de carga, error y vacío de una vista con datos.
- Condicionales con `&&` sobre un número: `count && <X/>` pinta `0`.
- Hooks dentro de condiciones, bucles o después de un `return`.

## Accesibilidad (no se recorta)
- HTML semántico primero: `button` para acciones, `a` para navegar, `label` ligado a cada campo.
- Todo control se alcanza y se activa con teclado, con foco visible. Los modales
  atrapan el foco y lo devuelven al cerrar.
- Iconos sin texto llevan `aria-label`. Los errores de formulario se asocian al
  campo con `aria-describedby`.

## Pruebas
- Vitest o Jest con Testing Library y `user-event`. Prueba lo que ve y hace el
  usuario: consulta por rol y nombre accesible, no por clases ni `data-testid` salvo último recurso.
- Red: MSW o el mock del cliente de datos; no mockees `fetch` a mano en cada prueba.
- Cubre carga, éxito, error y vacío, y el caso borde del plan. `findBy*` para lo
  asíncrono; nada de `setTimeout` ni esperas fijas.
- Snapshots solo para salidas pequeñas y estables. Un snapshot de página entera no prueba nada.

## Seguridad
- Todo lo que está en el bundle es público: ninguna llave secreta en variables
  `VITE_*`, `REACT_APP_*` o `NEXT_PUBLIC_*`.
- Tokens de sesión en cookie `httpOnly` cuando el backend lo permite; no en `localStorage`.
- `dangerouslySetInnerHTML` solo con contenido saneado (DOMPurify). Valida las URLs
  que vienen de datos antes de usarlas en `href` o `src` (cuidado con `javascript:`).
- La autorización se comprueba en el servidor. Ocultar un botón no protege nada.
