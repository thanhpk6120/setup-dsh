# PHP Impact Unit Test Loop

## Phase 1: Impact
- Determine the blast radius of the proposed change.
- Identify the specific classes, methods, and edge cases affected.

## Phase 2: Target
- Select the exact files and classes to test.
- Verify existing tests before adding new ones.

## Phase 3: Create test
- Write PHPUnit test cases.
- Use `createMock()` or `MockBuilder` for dependencies.
- Write strict assertions (`assertSame`, `assertEquals`).

## Phase 4: Run selective
- Run tests for the specific target only:
  ```bash
  XDEBUG_MODE=coverage vendor/bin/phpunit --filter TargetClassTest --coverage-clover clover.xml
  ```

## Phase 5: Loop-until-90
- Analyze `clover.xml`.
- Count covered `lines` and `methods` metrics for the targeted classes.
- If coverage is under 90%, write more tests for missing branches and return to Phase 4.

## Phase 6: Stop-and-ask
- If stuck on hard-to-test legacy code, untestable statics, or complex dependencies, stop and ask for guidance.
