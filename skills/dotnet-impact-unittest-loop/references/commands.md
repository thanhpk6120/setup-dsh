# .NET Unit Testing References

## Execution & Coverage

### Run specific tests with coverage
```bash
dotnet test --filter "FullyQualifiedName~MyCompany.MyProject.MyClassTests" --collect:"XPlat Code Coverage"
```

### Generate Coverage Report
Run this to convert Coverlet's output to a readable summary:
```bash
reportgenerator -reports:"TestResults/**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:"TextSummary"
```
View `coveragereport/Summary.txt` to inspect line and branch coverage percentages.

### Coverlet Threshold Configuration
To enforce coverage in CI/builds, add properties to the test `.csproj` or pass them via CLI:
```bash
dotnet test /p:CollectCoverage=true /p:Threshold=90 /p:ThresholdType=line
```

## Writing Tests (xUnit)

### Theory & InlineData
Use `[Theory]` for data-driven testing:
```csharp
[Theory]
[InlineData(null)]
[InlineData("")]
public void Method_ShouldThrow_WhenInputIsNullOrWhiteSpace(string input)
{
    // Arrange & Act
    Action act = () => _sut.Process(input);

    // Assert
    act.Should().Throw<ArgumentException>(); // using FluentAssertions
    // OR
    Assert.Throws<ArgumentException>(act);
}
```

## Mocking (Moq)

### Setup and Verify
```csharp
var repoMock = new Mock<IUserRepository>();

// Setup return value
repoMock.Setup(r => r.GetUserAsync(It.IsAny<int>()))
        .ReturnsAsync(new User { Id = 1, Name = "Test" });

// Setup exception
repoMock.Setup(r => r.SaveAsync(It.Is<User>(u => u == null)))
        .ThrowsAsync(new ArgumentNullException());

// Verify invocation
repoMock.Verify(r => r.GetUserAsync(1), Times.Once);
```

## Anti-Patterns
- **Mocking data structures:** Do not mock DTOs, string, or basic collections. Instantiate them directly.
- **Testing framework internals:** Don't write tests verifying that Entity Framework saves data, unless testing custom configuration/repositories (use InMemory/Sqlite).
- **Over-specifying Mocks:** Avoid `Times.Exactly(1)` unless the exact count is a strict business requirement. Prefer looser setups to reduce test fragility.
- **Testing private methods:** Test public APIs. If a private method requires isolated testing, it might belong to a new class.
