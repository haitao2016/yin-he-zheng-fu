# Backend Frameworks

Architecture patterns and best practices for 7 major backend frameworks.

## NestJS (TypeScript)

| Area | Pattern |
|------|---------|
| Architecture | Modules → Controllers → Services → Repositories |
| DI | Constructor injection with `@Injectable()` decorators |
| Validation | class-validator + class-transformer DTOs |
| Auth | Passport.js guards with JWT strategy |
| Testing | Jest with `@nestjs/testing` module |

```typescript
@Injectable()
export class UsersService {
  constructor(private readonly usersRepo: UsersRepository) {}

  async findById(id: string): Promise<User> {
    const user = await this.usersRepo.findOne(id);
    if (\!user) throw new NotFoundException(`User ${id} not found`);
    return user;
  }
}
```

## Django / DRF (Python)

| Area | Pattern |
|------|---------|
| Architecture | Models → Serializers → Views → URLs |
| ORM | QuerySet chaining, select_related/prefetch_related |
| Auth | Token/Session auth with DRF permissions |
| Testing | TestCase with fixtures, APIClient |

## FastAPI (Python Async)

| Area | Pattern |
|------|---------|
| Architecture | Routers → Dependencies → Services |
| Validation | Pydantic models for request/response |
| Async | async def endpoints, async DB drivers |
| Docs | Auto-generated OpenAPI/Swagger |

## Spring Boot (Java)

| Area | Pattern |
|------|---------|
| Architecture | Controller → Service → Repository (layered) |
| DI | Constructor injection (preferred over @Autowired) |
| Data | Spring Data JPA with derived queries |
| Config | application.yml with profiles |

## Other Frameworks

| Framework | Language | Key Pattern |
|-----------|----------|-------------|
| Laravel | PHP | Eloquent ORM, Artisan CLI, Blade templates, queues |
| Rails | Ruby | Convention over configuration, ActiveRecord, generators |
| .NET Core | C# | Minimal APIs, Entity Framework, middleware pipeline |
