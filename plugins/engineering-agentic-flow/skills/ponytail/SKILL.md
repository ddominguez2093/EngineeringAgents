---
name: ponytail
description: Escalera de decisión para escribir el mínimo código necesario y para auditar sobre-ingeniería en un diff. Úsala antes de implementar y al revisar.
---

# ponytail — perezoso con la solución, jamás con leer

Entiende el problema y el código a fondo; luego escribe lo menos posible.

## La escalera (en orden, antes de escribir)
1. **¿Necesita existir?** No construyas para un futuro imaginario.
2. **¿Ya existe en el repo?** Reusa o extiende antes de duplicar.
3. **¿Está en la librería estándar o en el framework?**
4. **¿Lo da la plataforma?** (navegador, iOS, Android, Spring).
5. **¿Lo hace una dependencia ya instalada?** No agregues otra.
6. **Solo entonces**: la implementación mínima que cumple el plan.

## Lo que nunca se poda
Validación en fronteras de confianza, manejo de errores, autorización,
accesibilidad y las pruebas del comportamiento nuevo. Minimalismo no es fragilidad.

## Como revisión
Señala para borrar: abstracciones con un solo uso, parámetros y opciones que nadie
pasa, capas que solo reenvían, código "por si acaso", dependencias nuevas para algo
de pocas líneas, y comentarios que repiten el código.

## Señal de éxito
Menos líneas, menos dependencias y menos superficie de bug, con la misma funcionalidad y la misma robustez.
