---
name: java
description: Experto en Java para el Coder y el Tester. Convenciones idiomaticas, framework de pruebas, build y gotchas de seguridad del ecosistema Java/Spring.
---

# Skill: Java

## Build & test
- Build: Maven (`mvn -q -DskipTests package`) o Gradle (`./gradlew build`).
- Test: JUnit 5 (`mvn test` / `./gradlew test`). Mockito para mocks. AssertJ para aserciones legibles.
- Lint/format: Checkstyle / Spotless / google-java-format.

## Convenciones
- Nombres: clases `PascalCase`, metodos/vars `camelCase`, constantes `UPPER_SNAKE`.
- Prefiere inmutabilidad (`final`, records para DTOs), `Optional` en vez de null.
- Inyeccion de dependencias por constructor (no field injection en Spring).
- Streams para transformaciones, pero no a costa de legibilidad.

## Pruebas
- Un test por comportamiento; nombres `should_do_x_when_y`.
- Arrange/Act/Assert. `@ParameterizedTest` para casos borde.
- Integracion Spring: `@SpringBootTest` solo cuando de verdad se necesita el contexto.

## Seguridad (para alinear con el Guardian)
- Nunca concatenes SQL: usa PreparedStatement / JPA parametrizado.
- Deserializacion: evita `ObjectInputStream` sobre datos no confiables.
- Valida input en el borde (Bean Validation `@Valid`).
- Spring Security: revisa authz por endpoint, no solo autenticacion.
