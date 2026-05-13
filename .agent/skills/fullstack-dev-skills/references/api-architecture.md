# API & Architecture Design

Patterns for REST, GraphQL, WebSocket, and microservices architecture.

## REST API Design

| Principle | Practice |
|-----------|----------|
| Resources | Plural nouns (`/users`, `/orders`) |
| Verbs | GET (read), POST (create), PUT (replace), PATCH (update), DELETE |
| Status Codes | 200 OK, 201 Created, 400 Bad Request, 401/403, 404 Not Found, 500 |
| Pagination | Cursor-based for large datasets; offset-based for small |
| Versioning | URL path (`/v1/`) or Accept header |
| HATEOAS | Include links for discoverability |

## GraphQL

| Area | Pattern |
|------|---------|
| Schema | Schema-first design with SDL |
| Resolvers | Thin resolvers, business logic in services |
| N+1 | Use DataLoader for batching |
| Federation | Apollo Federation for microservice composition |
| Subscriptions | WebSocket transport for real-time |

## WebSocket

| Pattern | Use Case |
|---------|----------|
| Pub/Sub | Chat rooms, notifications |
| Request/Response | RPC over WebSocket |
| Heartbeat | Connection keep-alive, dead connection detection |
| Reconnect | Exponential backoff with jitter |

## Microservices

| Pattern | Purpose |
|---------|---------|
| API Gateway | Single entry point, routing, auth |
| Service Discovery | Dynamic service location (Consul, K8s DNS) |
| Circuit Breaker | Fault tolerance, graceful degradation |
| Saga | Distributed transactions (choreography/orchestration) |
| Event Sourcing | Audit trail, temporal queries |
| CQRS | Separate read/write models for scale |
| Sidecar | Cross-cutting concerns (logging, auth proxy) |

## Architecture Decision Records (ADR)

```markdown
# ADR-001: Use PostgreSQL for primary data store

## Status: Accepted

## Context
We need a relational database for transactional data with ACID guarantees.

## Decision
Use PostgreSQL 16 with pgvector extension for semantic search.

## Consequences
- (+) Strong ACID, JSON support, full-text search
- (+) pgvector enables AI/embedding features
- (-) Requires operational expertise
- (-) Vertical scaling limits
```

## System Design Checklist

- [ ] Define non-functional requirements (latency, throughput, availability)
- [ ] Choose synchronous vs asynchronous communication
- [ ] Design for failure (circuit breakers, retries, timeouts)
- [ ] Plan data partitioning and replication strategy
- [ ] Define API contracts (OpenAPI/AsyncAPI)
- [ ] Document architecture decisions (ADR)
