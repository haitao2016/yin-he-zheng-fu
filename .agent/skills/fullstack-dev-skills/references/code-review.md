# Code Review Guide

Comprehensive code review methodology — from PR etiquette to domain-specific checklists.

## PR Author Responsibilities

Before requesting review:

1. **Self-review** — Read your own diff as if you were the reviewer
2. **Tests pass** — All CI checks green, no flaky test introduced
3. **Small PRs** — Under 400 lines of diff; split larger changes
4. **Clear description** — What changed, why, and how to test
5. **Link issues** — Reference the ticket/issue being addressed

### PR Description Template

```markdown
## What
Brief description of the change.

## Why
Context and motivation (link to issue/ticket).

## How
Implementation approach and key decisions.

## Testing
How was this tested? (unit, integration, manual steps)

## Rollback
How to revert if issues arise in production.
```

## Reviewer Responsibilities

1. **Timely** — Review within 24 hours (same business day ideal)
2. **Constructive** — Suggest improvements, don't just criticize
3. **Prioritize** — Distinguish blockers from nits
4. **Verify** — Pull and test locally for non-trivial changes

### Comment Prefixes

| Prefix | Meaning | Blocking? |
|--------|---------|-----------|
| `blocker:` | Must fix before merge | Yes |
| `concern:` | Should discuss, likely needs change | Yes |
| `suggestion:` | Improvement idea, optional | No |
| `nit:` | Style/preference, optional | No |
| `question:` | Seeking understanding | No |
| `praise:` | Highlighting good work | No |

## Review Checklist by Category

### 1. Correctness

- [ ] Logic handles all edge cases (null, empty, zero, negative, max values)
- [ ] Error handling is explicit — no empty catch blocks
- [ ] Return types are correct and consistent
- [ ] Boundary conditions are tested
- [ ] Concurrency is safe (no race conditions, proper synchronization)
- [ ] Data transformations preserve integrity
- [ ] Off-by-one errors checked in loops and indexing

### 2. Security

- [ ] No hardcoded secrets, tokens, API keys, or credentials
- [ ] User input validated and sanitized at boundaries
- [ ] SQL uses parameterized queries (no string interpolation/concatenation)
- [ ] Authentication and authorization checks present and correct
- [ ] No sensitive data in logs, error messages, or stack traces
- [ ] CORS, CSP, and security headers configured correctly
- [ ] File uploads validated (type, size, content)
- [ ] Rate limiting on public endpoints
- [ ] Dependencies scanned for known vulnerabilities

### 3. Performance

- [ ] No N+1 query patterns
- [ ] Large datasets use pagination, streaming, or cursors
- [ ] Expensive computations cached with invalidation strategy
- [ ] Database queries use appropriate indexes
- [ ] No unbounded collections growing in memory
- [ ] Resources (connections, file handles, streams) properly closed
- [ ] Async operations used where appropriate (I/O-bound work)
- [ ] No unnecessary re-renders (React) or recomputation

### 4. Architecture & Design

- [ ] Single Responsibility Principle followed
- [ ] New abstractions are justified (not premature)
- [ ] Dependencies flow in the right direction
- [ ] API contracts are stable and versioned
- [ ] No circular dependencies introduced
- [ ] Configuration externalized (not hardcoded)
- [ ] Feature flags used for gradual rollouts (when appropriate)

### 5. Testing

- [ ] Unit tests cover the change
- [ ] Edge cases and error paths tested
- [ ] Integration tests for cross-boundary interactions
- [ ] Test descriptions read as specifications
- [ ] No test interdependencies (each test is isolated)
- [ ] Mocks are minimal — only mock external dependencies
- [ ] Snapshot tests used sparingly (prefer explicit assertions)

### 6. Maintainability

- [ ] Names are clear, descriptive, and consistent
- [ ] No dead code or commented-out blocks
- [ ] Complex logic has explanatory comments (not what, but why)
- [ ] Functions are short (under 30 lines ideal, under 50 acceptable)
- [ ] DRY applied judiciously (2 is fine, 3+ = extract)
- [ ] Type annotations on public APIs
- [ ] No TODO/FIXME without linked issue

## Language-Specific Review Points

### TypeScript
- `strict: true` in tsconfig
- No `any` types (use `unknown` + type guards)
- Discriminated unions over type casting
- Prefer `readonly` for immutable data

### Python
- Type hints on all function signatures
- `dataclass` or Pydantic for data structures
- Context managers for resource management
- No bare `except:` — always specify exception type

### Go
- Errors checked immediately after every call
- `defer` for cleanup
- Interfaces defined by consumer, not provider
- No `panic` in library code

### Java/Kotlin
- Null safety (`Optional` in Java, `?` in Kotlin)
- Records/data classes for DTOs
- Dependency injection over static access
- Stream API used correctly (terminal operations, lazy evaluation)

### Rust
- Ownership model respected (minimize `clone`)
- `Result` over `unwrap` in production code
- Lifetimes annotated where compiler requires
- `unsafe` blocks documented with invariants

## Anti-Patterns to Flag

| Anti-Pattern | Problem | Better Approach |
|-------------|---------|-----------------|
| God function (100+ lines) | Hard to test, understand | Extract smaller functions |
| Boolean parameter | Unclear at call site | Use enum or separate functions |
| Magic numbers | Unclear meaning | Named constants |
| Stringly-typed | No compile-time checks | Enums, branded types |
| Shotgun surgery | One change = many files | Better encapsulation |
| Primitive obsession | Missing domain concepts | Value objects, types |
| Feature envy | Method uses another class more | Move method to that class |
| Temporal coupling | Methods must be called in order | Builder pattern, state machine |

## Giving Good Feedback

1. **Be specific** — Point to exact lines, suggest alternatives
2. **Explain why** — "This could cause X" not just "Don't do this"
3. **Offer code** — Show the improvement, don't just describe it
4. **Acknowledge trade-offs** — "This is simpler but trades off X"
5. **Ask questions** — "What happens when X is null?" opens dialogue
6. **Praise genuinely** — "Clean abstraction here" builds team culture
