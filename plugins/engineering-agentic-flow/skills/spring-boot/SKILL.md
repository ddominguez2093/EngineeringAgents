---
name: spring-boot
description: Guía de Spring Boot con Java (API REST, JPA, transacciones, seguridad, pruebas). Cárgala antes de escribir o revisar archivos .java de un servicio Spring, sus migraciones o su configuración.
---

# Spring Boot (Java)

Primero el proyecto: respeta su estructura de paquetes (por capa o por feature), su
herramienta de build, su versión de Java y de Spring Boot, y su estilo de errores.
Con Boot 3 los imports son `jakarta.*`, no `javax.*`.

## Comandos
- Maven: `./mvnw -q -B verify`. Gradle: `./gradlew -q check`. Usa el wrapper del repo.
- Formato: Spotless o Checkstyle si el proyecto los tiene.

## Capas
- **Controller**: traduce HTTP. Valida con `@Valid`, llama a un servicio y devuelve
  un DTO. Sin lógica de negocio, sin repositorios, sin entidades en la firma.
- **Service**: reglas de negocio y límites de transacción.
- **Repository**: acceso a datos. Sin reglas de negocio.
- **Nunca expongas ni recibas entidades JPA en la API.** DTOs de entrada y de salida
  como `record`, con un mapeo explícito. Evita serialización perezosa, ciclos y asignación masiva.
- Inyección por constructor con campos `final`. Nada de `@Autowired` en campos.
- Configuración con `@ConfigurationProperties` tipadas y validadas, no `@Value` regado por el código.

## JPA y transacciones
- `@Transactional` en métodos públicos del servicio; `readOnly = true` en las lecturas.
  No en controllers ni en repositorios.
- La anotación no aplica en llamadas dentro de la misma clase (`this.metodo()`) ni
  en métodos privados: el proxy no interviene.
- Por defecto solo hacen rollback las excepciones no comprobadas; con excepciones
  comprobadas usa `rollbackFor`.
- Relaciones `LAZY` por defecto (`@ManyToOne` y `@OneToOne` son `EAGER` si no lo indicas).
- **N+1**: si recorres una colección o una relación de cada fila, trae los datos con
  `JOIN FETCH`, `@EntityGraph` o una proyección a DTO. Compruébalo viendo el SQL generado.
- Todo listado va paginado (`Pageable`) y con un tope de tamaño.
- `equals`/`hashCode` de una entidad no usan el id generado ni todas las columnas;
  nada de `@Data` de Lombok en entidades.
- El esquema cambia con migraciones (Flyway o Liquibase), nunca con `ddl-auto` fuera
  de pruebas. Una migración ya aplicada no se edita: se agrega otra. Piensa en los
  datos existentes y en que la versión anterior de la app sigue corriendo durante el despliegue.
- Bloqueo optimista (`@Version`) donde dos peticiones pueden pisarse.

## API
- Códigos HTTP correctos y errores uniformes con `@RestControllerAdvice` y
  `ProblemDetail` (o el formato del proyecto). No filtres trazas ni mensajes de SQL.
- Valida en la frontera con Bean Validation en los DTOs; las reglas de negocio se validan en el servicio.
- Las operaciones que pueden reintentarse (pagos, creación) necesitan idempotencia.
- Fechas en UTC con `Instant` u `OffsetDateTime`; dinero con `BigDecimal`, nunca `double`.

## Errores frecuentes (lista de control para revisar)
- Endpoint que carga un recurso por id sin comprobar que pertenece al usuario autenticado (IDOR).
- Entidad usada como cuerpo de la petición: el cliente puede fijar `id`, `role` u `owner`.
- `LazyInitializationException` tapada activando `open-in-view` o volviendo `EAGER` la relación.
- `Optional.get()` sin comprobar; `findById(...).get()`.
- Llamadas HTTP o a colas dentro de una transacción de base de datos larga.
- `catch (Exception e)` que registra y sigue, dejando la transacción a medias.
- Estado mutable en un bean singleton; `@Async` o `@Scheduled` sin manejo de errores.
- Consulta con concatenación de cadenas en lugar de parámetros.
- Registrar tokens, contraseñas o datos personales.

## Pruebas
- Unitarias de servicios con JUnit 5, Mockito y AssertJ, sin levantar Spring.
- Por capa: `@WebMvcTest` para controllers (validación, códigos, seguridad con
  `@WithMockUser`), `@DataJpaTest` para repositorios y consultas.
- La base de pruebas es la misma que en producción con Testcontainers; H2 oculta diferencias de SQL.
- `@SpringBootTest` solo para flujos de punta a punta: es lento y se paga en cada corrida.
- Prueba la autorización: el usuario equivocado recibe 403 o 404, no el dato.

## Seguridad
- Regla de acceso explícita para cada ruta nueva en la configuración de seguridad, y
  autorización por recurso en el servicio (`@PreAuthorize` o comprobación de dueño).
- Secretos por variables de entorno o un gestor de secretos, nunca en `application.yml` versionado.
- Actuator: expón solo `health` e `info` públicamente.
- CORS con orígenes concretos, no `*` con credenciales. No desactives CSRF en una app con sesión por cookie.
- Contraseñas con `PasswordEncoder` (BCrypt o Argon2). Subida de archivos con límite de tamaño y tipo validado.
