# Testing & Quality Assurance

Comprehensive testing strategy across unit, integration, E2E, performance, and security testing — with TDD methodology and anti-patterns to avoid.

## Test Pyramid

```
        /   E2E    \          — Few, slow, high confidence, brittle
       / Integration \       — Medium count, API/DB/service boundary
      /  Unit Tests    \     — Many, fast, isolated, deterministic
```

**Ratio guideline**: 70% unit / 20% integration / 10% E2E

## TDD Iron Laws

Test-Driven Development follows three strict rules:

```
1. RED    — Write a failing test for the next piece of behavior
2. GREEN  — Write the MINIMUM code to make the test pass
3. REFACTOR — Clean up while all tests pass
```

### TDD Commandments

1. **Never write production code without a failing test**
2. **Write only enough test to fail** (compilation failures count)
3. **Write only enough production code to pass the failing test**
4. **Refactor only when all tests are green**
5. **Each test should test ONE behavior** (not one method — one behavior)

### When to Use TDD

| Scenario | Use TDD? |
|----------|----------|
| Business logic with clear rules | Yes — perfect fit |
| Bug fixes (regression prevention) | Yes — write failing test first |
| Algorithm implementation | Yes — test cases drive correctness |
| Exploratory/prototype code | No — spike first, then TDD the real impl |
| UI layout/styling | No — visual testing more appropriate |
| Integration glue code | Partial — TDD the logic, integration test the wiring |

## Unit Testing

### Jest / Vitest (JavaScript/TypeScript)

```javascript
describe('calculateDiscount', () => {
  it('applies 10% discount for premium users', () => {
    const result = calculateDiscount({ price: 100, userTier: 'premium' });
    expect(result).toBe(90);
  });

  it('returns original price for standard users', () => {
    const result = calculateDiscount({ price: 100, userTier: 'standard' });
    expect(result).toBe(100);
  });

  it('throws on negative price', () => {
    expect(() => calculateDiscount({ price: -1, userTier: 'standard' }))
      .toThrow('Price must be non-negative');
  });

  it('handles zero price', () => {
    const result = calculateDiscount({ price: 0, userTier: 'premium' });
    expect(result).toBe(0);
  });
});
```

### pytest (Python)

```python
import pytest
from app.config import AppConfig

@pytest.fixture
def config_file(tmp_path):
    cfg = tmp_path / "config.txt"
    cfg.write_text("host=localhost\nport=8080\n")
    return cfg

@pytest.mark.parametrize("port,valid", [
    (80, True), (8080, True), (443, True),
    (0, False), (-1, False), (65536, False),
])
def test_port_validation(port: int, valid: bool) -> None:
    if valid:
        config = AppConfig(host="localhost", port=port)
        assert config.port == port
    else:
        with pytest.raises(ValueError, match="Invalid port"):
            AppConfig(host="localhost", port=port)
```

### Go (Table-Driven Tests)

```go
func TestParsePort(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {"valid port", "8080", 8080, false},
        {"min port", "1", 1, false},
        {"max port", "65535", 65535, false},
        {"zero", "0", 0, true},
        {"negative", "-1", 0, true},
        {"overflow", "65536", 0, true},
        {"non-numeric", "abc", 0, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParsePort(tt.input)
            if tt.wantErr {
                require.Error(t, err)
            } else {
                require.NoError(t, err)
                assert.Equal(t, tt.want, got)
            }
        })
    }
}
```

## Integration Testing

| Area | Tools | Key Pattern |
|------|-------|-------------|
| API | Supertest (Node), httpx (Python), RestAssured (Java) | Start server, make request, assert response |
| Database | Testcontainers, in-memory DB, transaction rollback | Use real DB in Docker, rollback after each test |
| External APIs | WireMock, nock, responses, VCR | Record/replay HTTP interactions |
| Message Queues | Testcontainers (Kafka, RabbitMQ) | Produce, consume, assert |

### Database Test Pattern

```python
@pytest.fixture
def db_session():
    """Each test gets a fresh transaction that rolls back."""
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

## E2E Testing

| Tool | Best For | Key Feature |
|------|----------|-------------|
| Playwright | Cross-browser, CI/CD | Auto-waiting, network interception, codegen |
| Cypress | Component + E2E | Real-time reloading, time travel debugging |

```typescript
// Playwright example
test('user can log in and see dashboard', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'user@example.com');
  await page.fill('[data-testid="password"]', 'password123');
  await page.click('[data-testid="login-button"]');
  
  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('h1')).toHaveText('Welcome back');
});
```

## Performance Testing

| Tool | Use Case | Command |
|------|----------|---------|
| k6 | Load testing | `k6 run --vus 100 --duration 30s script.js` |
| Artillery | Scenario-based | `artillery run scenario.yml` |
| Lighthouse | Web perf metrics | `npx lighthouse https://example.com` |
| hyperfine | CLI benchmarking | `hyperfine './program --input data'` |

## Testing Anti-Patterns

Avoid these common testing mistakes:

| # | Anti-Pattern | Problem | Better Approach |
|---|-------------|---------|-----------------|
| 1 | **Testing implementation** | Tests break on refactor | Test behavior/outcomes, not internal methods |
| 2 | **Flaky tests ignored** | False confidence, CI noise | Quarantine immediately, fix within 1 sprint |
| 3 | **Order-dependent tests** | Pass alone, fail in suite | Each test sets up its own state |
| 4 | **Excessive mocking** | Tests pass but real code fails | Mock at boundaries, use fakes for complex deps |
| 5 | **No assertions** | Test always passes | Every test needs explicit assertions |
| 6 | **Copy-paste tests** | Hard to maintain | Use parameterized tests, test factories |
| 7 | **Slow unit tests** | Developers skip them | No I/O in unit tests, mock external calls |
| 8 | **Testing trivial code** | Wasted effort, maintenance burden | Test behavior, not getters/setters |
| 9 | **Giant test files** | Hard to navigate and maintain | One test file per module, organized by behavior |
| 10 | **Snapshot overuse** | Large diffs, rubber-stamp updates | Use snapshots only for serialization formats |

## Test Quality Checklist

- [ ] Tests cover happy paths AND error/edge cases
- [ ] Each test has a single, clear reason to fail
- [ ] Test descriptions read as behavior specifications
- [ ] External dependencies mocked at boundaries only
- [ ] No flaky tests in CI (quarantine if found)
- [ ] Test data is explicit (no shared mutable fixtures)
- [ ] Assertions are specific (not just truthiness)
- [ ] Tests run in CI/CD on every PR

## Rules

### Always
- Write tests that describe behavior, not implementation
- Use meaningful test names: `test_expired_token_returns_401`
- Assert specific values (not just `toBeTruthy`)
- Run full test suite before merging
- Keep tests fast (unit: <100ms each, suite: <2 min)

### Never
- Skip error-path testing
- Use production data in tests
- Create order-dependent tests
- Ignore flaky tests (quarantine and fix)
- Test private methods directly
- Use `sleep()` for timing (use polling/retry)
