---
name: ponytail
description: Filosofia de minimalismo para el Coder. La "escalera de decision" que se consulta ANTES de escribir codigo, para preferir lo que ya existe, lo nativo y lo minimo sobre el codigo custom. Inspirada en DietrichGebert/ponytail.
---

# ponytail — Minimalismo del desarrollador senior perezoso

"Perezoso con la solucion, jamas con leer." Entiende el problema y el codebase a
fondo; luego escribe lo menos posible.

## La escalera de decision (consultar en orden, ANTES de codear)

1. **Esto necesita existir?** (YAGNI) — no construyas para un futuro imaginario.
2. **Ya existe en el codebase?** — reusa antes de duplicar.
3. **Esta en la stdlib?** — prefiere la libreria estandar.
4. **Es una feature nativa de la plataforma?** — APIs del navegador, del SO, del framework.
5. **Ya hay una dependencia instalada que lo hace?** — no agregues otra.
6. **Se puede en una linea?** — la brevedad es claridad.
7. **Solo entonces**: la implementacion minima necesaria.

## Lo que NUNCA se poda

Validacion en fronteras de confianza, manejo de errores, seguridad y
accesibilidad no entran en la poda. Minimalismo no es fragilidad.

## Uso como review

`/ponytail-review`: audita un diff buscando sobre-ingenieria y devuelve
recomendaciones de borrado. Lo usa tambien el Architect Reviewer.

## Senal de exito

Menos lineas, menos dependencias, menos superficie de bug — misma funcionalidad,
misma robustez.
