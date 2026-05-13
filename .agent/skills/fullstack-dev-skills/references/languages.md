# Language Specialists

Best practices, patterns, and tooling for 12 programming languages.

## Python (3.11+)

**Core Principles**: Type-safe, async-first, production-ready code.

| Area | Practice |
|------|----------|
| Types | Complete type hints on all signatures; `X \| None` over `Optional[X]` |
| Async | async/await for all I/O-bound operations |
| Data | Dataclasses over manual `__init__`; Pydantic for validation |
| Testing | pytest with fixtures, parametrize, >90% coverage |
| Tooling | mypy --strict, black, ruff |
| Style | Google-style docstrings, PEP 8 |

```python
from dataclasses import dataclass, field

@dataclass
class AppConfig:
    host: str
    port: int
    debug: bool = False
    allowed_origins: list[str] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not (1 <= self.port <= 65535):
            raise ValueError(f"Invalid port: {self.port}")

# Async pattern
async def fetch_user(user_id: str) -> User | None:
    async with httpx.AsyncClient() as client:
        response = await client.get(f"/users/{user_id}")
        if response.status_code == 404:
            return None
        response.raise_for_status()
        return User(**response.json())

# Context manager for resource management
from contextlib import asynccontextmanager

@asynccontextmanager
async def db_transaction():
    conn = await pool.acquire()
    tx = await conn.begin()
    try:
        yield conn
        await tx.commit()
    except Exception:
        await tx.rollback()
        raise
    finally:
        await pool.release(conn)
```

## TypeScript (Strict Mode)

**Core Principles**: Advanced types, type guards, generics, utility types.

| Area | Practice |
|------|----------|
| Strict | Enable `strict: true` in tsconfig.json |
| Types | Prefer `interface` for objects, `type` for unions/intersections |
| Guards | Use type predicates (`x is Foo`) for runtime narrowing |
| Generics | Constrain with `extends`, use utility types (Partial, Pick, Omit) |
| Nulls | Use optional chaining (`?.`) and nullish coalescing (`??`) |

```typescript
// Discriminated unions for exhaustive handling
type Result<T> =
  | { status: "success"; data: T }
  | { status: "error"; error: string }
  | { status: "loading" };

function handleResult<T>(result: Result<T>): string {
  switch (result.status) {
    case "success": return `Got: ${JSON.stringify(result.data)}`;
    case "error": return `Error: ${result.error}`;
    case "loading": return "Loading...";
    // TypeScript ensures exhaustiveness — adding a new status
    // without handling it here causes a compile error
  }
}

// Type guard with predicate
interface User {
  id: string;
  name: string;
  email: string;
  role: "admin" | "user";
}

function isAdmin(user: User): user is User & { role: "admin" } {
  return user.role === "admin";
}

// Generic with constraint
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// Branded types for type-safe IDs
type UserId = string & { readonly __brand: "UserId" };
type OrderId = string & { readonly __brand: "OrderId" };

function createUserId(id: string): UserId { return id as UserId; }
// Now: getUserById(orderId) is a compile error\!
```

## Go

**Core Principles**: Simplicity, concurrency, explicit error handling.

| Area | Practice |
|------|----------|
| Errors | Return `error` as last value; wrap with `fmt.Errorf("%w", err)` |
| Concurrency | Goroutines + channels; use `context.Context` for cancellation |
| Interfaces | Small interfaces (1-3 methods); accept interfaces, return structs |
| Testing | Table-driven tests with `t.Run()` subtests |

```go
// Error wrapping and handling
func GetUser(ctx context.Context, id string) (*User, error) {
    row := db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", id)
    
    var u User
    if err := row.Scan(&u.ID, &u.Name, &u.Email); err \!= nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, fmt.Errorf("user %s not found: %w", id, ErrNotFound)
        }
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return &u, nil
}

// Concurrency with context and errgroup
func FetchAll(ctx context.Context, urls []string) ([]Response, error) {
    g, ctx := errgroup.WithContext(ctx)
    results := make([]Response, len(urls))

    for i, url := range urls {
        i, url := i, url // capture loop vars
        g.Go(func() error {
            resp, err := fetch(ctx, url)
            if err \!= nil {
                return fmt.Errorf("fetching %s: %w", url, err)
            }
            results[i] = resp
            return nil
        })
    }

    if err := g.Wait(); err \!= nil {
        return nil, err
    }
    return results, nil
}

// Interface — accept interface, return struct
type Repository interface {
    GetUser(ctx context.Context, id string) (*User, error)
    SaveUser(ctx context.Context, user *User) error
}

type postgresRepo struct {
    db *sql.DB
}

func NewPostgresRepo(db *sql.DB) *postgresRepo {
    return &postgresRepo{db: db}
}
```

## Rust

**Core Principles**: Ownership, lifetimes, zero-cost abstractions.

| Area | Practice |
|------|----------|
| Ownership | Prefer borrowing (`&T`, `&mut T`) over cloning |
| Errors | `Result<T, E>` with thiserror/anyhow; `?` operator for propagation |
| Async | tokio runtime; `async fn` + `.await`; `Pin<Box<dyn Future>>` for dynamic |
| Unsafe | Minimize; document invariants; encapsulate in safe wrappers |

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("user {0} not found")]
    NotFound(String),
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("validation error: {0}")]
    Validation(String),
}

// Result type alias for convenience
type Result<T> = std::result::Result<T, AppError>;

// Error propagation with ? operator
async fn get_user(pool: &PgPool, id: &str) -> Result<User> {
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await?  // converts sqlx::Error to AppError::Database
        .ok_or_else(|| AppError::NotFound(id.to_string()))?;
    
    Ok(user)
}

// Builder pattern for complex construction
pub struct ServerConfig {
    host: String,
    port: u16,
    max_connections: usize,
}

impl ServerConfig {
    pub fn builder() -> ServerConfigBuilder {
        ServerConfigBuilder::default()
    }
}

#[derive(Default)]
pub struct ServerConfigBuilder {
    host: Option<String>,
    port: Option<u16>,
    max_connections: Option<usize>,
}

impl ServerConfigBuilder {
    pub fn host(mut self, host: impl Into<String>) -> Self {
        self.host = Some(host.into());
        self
    }
    pub fn port(mut self, port: u16) -> Self {
        self.port = Some(port);
        self
    }
    pub fn build(self) -> Result<ServerConfig> {
        Ok(ServerConfig {
            host: self.host.unwrap_or_else(|| "localhost".to_string()),
            port: self.port.unwrap_or(8080),
            max_connections: self.max_connections.unwrap_or(100),
        })
    }
}
```

## Java (Enterprise)

**Core Principles**: Spring ecosystem, design patterns, enterprise-grade.

```java
// Records for DTOs (Java 16+)
public record UserDTO(String id, String name, String email) {
    public UserDTO {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(email, "email must not be null");
    }
}

// Sealed classes for restricted hierarchies (Java 17+)
public sealed interface Shape
    permits Circle, Rectangle, Triangle {
    double area();
}

public record Circle(double radius) implements Shape {
    public double area() { return Math.PI * radius * radius; }
}

// Pattern matching with switch (Java 21+)
static String describe(Shape shape) {
    return switch (shape) {
        case Circle c -> "Circle with radius " + c.radius();
        case Rectangle r -> "Rectangle " + r.width() + "x" + r.height();
        case Triangle t -> "Triangle with base " + t.base();
    };
}

// Virtual threads for concurrent I/O (Java 21+)
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    List<Future<Response>> futures = urls.stream()
        .map(url -> executor.submit(() -> fetch(url)))
        .toList();
}
```

## Other Languages

| Language | Key Focus | Essential Patterns |
|----------|-----------|-------------------|
| C++ (17/20/23) | RAII, smart pointers, move semantics | `std::unique_ptr`, `std::optional`, concepts, ranges |
| Swift | SwiftUI, structured concurrency, actors | `async let`, `TaskGroup`, `@MainActor`, property wrappers |
| Kotlin | Coroutines, Flow, null safety | `suspend fun`, `Flow<T>`, `sealed class`, scope functions |
| C# (.NET 8+) | LINQ, records, pattern matching | `record`, `is` pattern, `async IAsyncEnumerable`, `Span<T>` |
| PHP (8.2+) | Typed properties, enums, fibers | `readonly class`, `enum`, `match`, union types |
| SQL | Window functions, CTEs, optimization | `WITH` recursive, `ROW_NUMBER()`, `EXPLAIN ANALYZE`, covering indexes |
