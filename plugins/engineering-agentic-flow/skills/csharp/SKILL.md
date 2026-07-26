---
name: csharp
description: Experto en C#/.NET para el Coder y el Tester. xUnit/NUnit, dotnet CLI, patrones async, y seguridad del ecosistema .NET.
---

# Skill: C# / .NET

## Build & test
- Build: `dotnet build`. Test: `dotnet test` (xUnit o NUnit; Moq/NSubstitute para mocks; FluentAssertions).
- Format/lint: `dotnet format`, analizadores Roslyn.

## Convenciones
- `PascalCase` para tipos/metodos/propiedades, `camelCase` para locales; `I`-prefijo para interfaces.
- `async`/`await` de punta a punta; nunca `.Result`/`.Wait()` (deadlocks). Sufijo `Async`.
- Nullable reference types habilitados; evita `null!`.
- Records para inmutables; `using` para `IDisposable`.

## Pruebas
- AAA. `[Theory]`/`[InlineData]` para casos borde. Inyeccion de dependencias para testear.

## Seguridad (alinear con Guardian)
- EF Core / consultas parametrizadas; jamas string interpolation en SQL.
- Valida modelos (`[Required]`, data annotations / FluentValidation).
- No expongas stack traces en prod; revisa authorization policies por endpoint.
