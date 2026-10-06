# PHPUnit Commands and References

## Execution
Run with Xdebug coverage:
```bash
XDEBUG_MODE=coverage vendor/bin/phpunit --filter ClassNameTest --coverage-clover clover.xml
```

Run with PCOV (faster):
```bash
php -d pcov.enabled=1 vendor/bin/phpunit --filter ClassNameTest --coverage-clover clover.xml
```

## Mocking
Basic mock (`createMock`):
```php
$mock = $this->createMock(Dependency::class);
$mock->method('someMethod')->willReturn('value');
```

MockBuilder (for complex cases, e.g., mocking specific methods only):
```php
$mock = $this->getMockBuilder(Dependency::class)
    ->onlyMethods(['methodToMock'])
    ->disableOriginalConstructor()
    ->getMock();
```

## phpunit.xml Configuration
To generate Clover reports and configure coverage targets:
```xml
<phpunit>
    <coverage processUncoveredFiles="true">
        <include>
            <directory suffix=".php">src</directory>
        </include>
        <report>
            <clover outputFile="clover.xml"/>
            <text outputFile="php://stdout" showUncoveredFiles="false" showOnlySummary="true"/>
        </report>
    </coverage>
</phpunit>
```
*Note: Enforcement of the 90% threshold is typically done by parsing `clover.xml` during the loop, as strict built-in thresholds depend on specific PHPUnit versions.*

## Anti-patterns
- **Mocking the system under test**: Never mock the class you are actively testing.
- **Testing implementation details**: Assert on public outputs and state, not private properties.
- **Over-mocking**: If a dependency is a simple value object or array, use the real thing instead of a mock.
- **Ignoring branch coverage**: High line coverage does not guarantee logical branches (e.g., empty `if` blocks) are tested.
