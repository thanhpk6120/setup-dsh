# .NET Impact Unit Test Loop

This skill drives the creation of robust unit tests in .NET projects using xUnit, Moq, Coverlet, and ReportGenerator. Follow these phases strictly.

## Phase 1: Impact Analysis
Analyze the changed or newly added code. Identify the public interfaces, external dependencies, and critical logic paths that require validation.

## Phase 2: Target Selection
Select the specific classes or methods that need coverage based on the impact analysis. Do not test framework internals or trivial boilerplate code.

## Phase 3: Create Tests
Use xUnit and Moq to write the tests. Ensure you cover:
- Happy paths
- Edge cases and null inputs
- Error conditions and exceptions
- Branching logic
Use `[Fact]` for single cases and `[Theory]` with `[InlineData]` or `[MemberData]` for parameterized scenarios.

## Phase 4: Selective Run
Run tests selectively targeting the specific class or namespace, and collect coverage data using Coverlet:
```bash
dotnet test --filter "FullyQualifiedName~Your.Namespace.TargetClass" --collect:"XPlat Code Coverage"
```

## Phase 5: Loop-until-90
Extract the coverage metrics using ReportGenerator on the generated `cobertura.xml`:
```bash
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:"TextSummary"
```
Review the text summary. If line coverage for the target is below 90%, identify missing branches or lines, write additional tests, and repeat from Phase 4.

## Phase 6: Stop-and-ask
If you cannot mock a specific dependency, encounter a complex private state, or cannot reach 90% coverage after 3 iterations, stop and ask the user for guidance.
