---
name: fullstack-dev-skills
description: "Patterns and architecture guide for fullstack software development, covering language best practices, backend/frontend frameworks, infrastructure, testing, security, DevOps, and AI/ML across 12 specialist domains with workflow orchestration."
---

# Fullstack Development Skills

A comprehensive engineering knowledge base covering 12 specialist domains — from language-level best practices to production deployment — with systematic workflows for feature development, debugging, code review, and security audits.

## Skill Selection Guide

Match your current task to the right specialist domain:

| Task | Domain | Reference |
|------|--------|-----------|
| Python/TypeScript/Go/Rust/Java/C#/C++/Swift/Kotlin/PHP code | Language Specialists | `references/languages.md` |
| NestJS/Django/FastAPI/Spring Boot/Laravel/Rails/.NET API | Backend Frameworks | `references/backend-frameworks.md` |
| React/Next.js/Vue/Angular/React Native/Flutter UI | Frontend & Mobile | `references/frontend-mobile.md` |
| Docker/Kubernetes/Terraform/Cloud architecture | Infrastructure & Cloud | `references/infrastructure.md` |
| REST/GraphQL/WebSocket/Microservices design | API & Architecture | `references/api-architecture.md` |
| Unit/Integration/E2E/Performance/Security testing | Testing & QA | `references/testing.md` |
| CI/CD/GitOps/Deployment/Monitoring/SRE | DevOps & Reliability | `references/devops.md` |
| Authentication/OWASP/Input validation/Encryption | Security | `references/security.md` |
| Pandas/Spark/ML pipelines/Prompt engineering/RAG/Fine-tuning | Data & AI | `references/data-ai.md` |
| Salesforce/Shopify/WordPress/Atlassian platform work | Platform Specialists | `references/platforms.md` |
| Legacy modernization/Embedded systems/Game dev | Specialized | `references/specialized.md` |
| Systematic debugging across all languages | Debugging | `references/debugging.md` |
| Code review checklists and PR best practices | Code Review | `references/code-review.md` |
| Project lifecycle workflows (9 phases) | Workflows | `references/workflows.md` |

## 9 Workflow Commands

Use these workflows to guide any project phase. Each workflow is a structured sequence — follow the steps in order.

| # | Workflow | When to Use | Reference |
|---|----------|-------------|-----------|
| 1 | **Epic Discovery** | Starting a new epic/project — requirements gathering, scope definition | `references/workflows.md` §1 |
| 2 | **Feature Development** | Implementing a well-defined feature from design to merge | `references/workflows.md` §2 |
| 3 | **Bug Investigation** | Systematic debugging and root cause analysis | `references/workflows.md` §3 |
| 4 | **Code Review** | Reviewing PRs for correctness, security, performance | `references/workflows.md` §4 |
| 5 | **Security Audit** | Auditing code for vulnerabilities, compliance, threat modeling | `references/workflows.md` §5 |
| 6 | **Performance Optimization** | Profiling, bottleneck identification, optimization | `references/workflows.md` §6 |
| 7 | **Migration Planning** | Planning major version upgrades, framework migrations | `references/workflows.md` §7 |
| 8 | **Production Deployment** | Pre-deploy checks, rollout strategy, rollback plan | `references/workflows.md` §8 |
| 9 | **Retrospective** | Post-mortem analysis, lessons learned, process improvement | `references/workflows.md` §9 |

## Code Review Quick Checklist

Before approving any PR, verify all items. Full guide: `references/code-review.md`

### Correctness
- [ ] Logic handles all edge cases (null, empty, boundary values)
- [ ] Error handling is explicit — no silent swallows
- [ ] Concurrency is safe (no race conditions, proper locking)
- [ ] Data types are correct (no implicit coercions causing bugs)

### Security
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] User input is validated and sanitized
- [ ] SQL uses parameterized queries (no string interpolation)
- [ ] Authentication/authorization checks are in place
- [ ] No sensitive data in logs or error messages

### Performance
- [ ] No N+1 queries or unbounded loops
- [ ] Large datasets use pagination or streaming
- [ ] Resources (connections, file handles) are properly closed
- [ ] Caching is used where appropriate (with invalidation strategy)

### Maintainability
- [ ] Functions/methods have single responsibility
- [ ] Names are clear and descriptive
- [ ] No dead code, commented-out blocks, or TODOs without tracking
- [ ] Tests cover the change (unit + integration as needed)

## Universal Best Practices

### Always Do

- Use TypeScript strict mode / mypy strict / equivalent for your language
- Write meaningful test descriptions that read as specifications
- Use parameterized queries (never string-interpolated SQL)
- Hash passwords with bcrypt/argon2 (never MD5/SHA-1)
- Store secrets in environment variables or secret managers
- Implement health checks and readiness probes
- Use infrastructure as code (never manual changes)
- Document rollback procedures before deploying
- Clean up effects, connections, and resources (prevent leaks)
- Test happy paths AND error/edge cases
- Use semantic versioning for packages and APIs
- Prefer composition over inheritance
- Handle errors at the appropriate level (don't over-catch)

### Never Do

- Skip type annotations on public APIs
- Use mutable default arguments
- Trust user input without validation
- Expose sensitive data in logs or error responses
- Store secrets in code or CI/CD variables
- Use `latest` tag in production containers
- Deploy without staging verification
- Ignore flaky tests — quarantine and fix them
- Make multiple debugging changes at once
- Skip error boundaries / error handling in production
- Commit directly to main/master without review
- Use force push on shared branches

## Recommended Combinations

| Scenario | Domains to Combine |
|----------|-------------------|
| Feature Development | Language + Framework + Testing + DevOps |
| Security-Focused Dev | Language + Security + Testing + Code Review |
| System Architecture | Architecture + Infrastructure + Monitoring |
| API Development | API Design + Backend Framework + Testing |
| Cloud Infrastructure | Kubernetes + Terraform + Cloud + SRE + Monitoring |
| Mobile Apps | Frontend/Mobile + API Design + DevOps |
| Data Engineering | Pandas + Spark + ML Pipeline + Monitoring |
| LLM Projects | Prompt Engineer + RAG + Fine-Tuning + Python |
| Modernization | Legacy Modernizer + Architecture + Language + Testing |
| Production Incident | Debugging + DevOps + Workflows §9 (Retrospective) |

## Output Format

When implementing features, always provide:

1. **Implementation code** with proper types and error handling
2. **Test file** covering happy paths and edge cases
3. **Configuration** requirements (env vars, dependencies)
4. **Key decisions** explained briefly
5. **Rollback/revert** procedure (for deployments)
