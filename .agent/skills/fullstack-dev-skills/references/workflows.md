# Project Lifecycle Workflows

9 structured workflows covering the complete software development lifecycle. Each workflow is a step-by-step process — follow in order, skip steps only when explicitly justified.

## §1 Epic Discovery

**When**: Starting a new project, epic, or major feature. Defines scope before any code is written.

```
Step 1: GATHER REQUIREMENTS
   - Interview stakeholders / parse the brief
   - Identify user personas and use cases
   - List functional requirements (MUST, SHOULD, COULD)
   - List non-functional requirements (performance, security, scale)

Step 2: DEFINE SCOPE
   - Create user stories with acceptance criteria
   - Identify technical constraints and dependencies
   - Map system boundaries (what is in/out of scope)
   - Estimate complexity (T-shirt sizing: S/M/L/XL)

Step 3: ARCHITECTURE SPIKE
   - Prototype critical unknowns
   - Evaluate technology choices
   - Document Architecture Decision Records (ADRs)
   - Identify integration points with existing systems

Step 4: BREAK DOWN
   - Split epic into deliverable stories/tasks
   - Define MVP vs. full scope
   - Identify parallelizable work streams
   - Create dependency graph

Step 5: DELIVERABLES
   - Technical design document
   - Architecture diagrams (C4 model recommended)
   - Task breakdown with estimates
   - Risk register with mitigations
```

## §2 Feature Development

**When**: Implementing a well-defined feature from design to merge.

```
Step 1: ANALYZE
   - Read the spec/ticket completely
   - Identify affected components and data flows
   - Check for existing patterns in the codebase
   - List questions and resolve before coding

Step 2: DESIGN
   - Choose patterns (see references/api-architecture.md)
   - Define data models and API contracts
   - Plan state management approach
   - Sketch component/module hierarchy

Step 3: IMPLEMENT
   - Create feature branch from latest main
   - Write code with types and error handling
   - Follow language-specific best practices (references/languages.md)
   - Commit logical units with meaningful messages

Step 4: VALIDATE
   - Run linter, type checker, formatter
   - Fix ALL warnings and errors (no suppressions without justification)
   - Self-review the diff

Step 5: TEST
   - Write unit tests for business logic
   - Write integration tests for API/DB interactions
   - Cover happy paths, error paths, and edge cases
   - Verify test coverage meets project threshold

Step 6: REVIEW
   - Open PR with clear description (see references/code-review.md)
   - Request review from relevant team members
   - Address all blocking feedback before merge
   - Squash or rebase for clean history

Step 7: DEPLOY
   - Merge to main, verify CI passes
   - Deploy to staging, run smoke tests
   - Deploy to production (blue-green or canary)
   - Monitor metrics and error rates

Step 8: VERIFY
   - Confirm feature works in production
   - Check monitoring dashboards
   - Close the ticket with verification notes
```

## §3 Bug Investigation

**When**: Systematically diagnosing and fixing a reported bug.

```
Step 1: TRIAGE
   - Assess severity and impact (P0/P1/P2/P3)
   - Check: Is this a regression? (git bisect)
   - Check: Is this environment-specific?
   - Gather logs, stack traces, reproduction steps

Step 2: REPRODUCE
   - Create minimal reproduction case
   - Verify reproduction is consistent
   - Document exact steps, environment, and data state
   - If intermittent: add logging to capture next occurrence

Step 3: ISOLATE
   - Binary search through code (git bisect or manual)
   - Add targeted logging/tracing
   - Test hypotheses one at a time
   - Narrow to specific module/function/line

Step 4: ROOT CAUSE
   - Identify the fundamental cause (not just symptoms)
   - Trace the causal chain from trigger to failure
   - Check for related bugs (same root cause, different symptoms)
   - Document the root cause analysis

Step 5: FIX
   - Implement the minimal correct fix
   - Write regression test BEFORE fixing (verify it fails)
   - Apply fix, verify regression test passes
   - Check for similar patterns elsewhere in codebase

Step 6: PREVENT
   - Add monitoring/alerting for this failure mode
   - Update documentation if behavior was unclear
   - Consider guardrails (linter rules, type constraints)
   - Share findings with the team (post-mortem if P0/P1)
```

## §4 Code Review Process

**When**: Reviewing a pull request for correctness, security, and quality.

```
Step 1: CONTEXT
   - Read PR description, linked tickets, and design docs
   - Understand the intent and scope of the change
   - Check PR size (>400 lines = request split)

Step 2: HIGH-LEVEL REVIEW
   - Does the approach make sense architecturally?
   - Are there simpler alternatives?
   - Does it follow existing patterns in the codebase?

Step 3: LINE-BY-LINE REVIEW
   - Apply checklist from references/code-review.md
   - Correctness → Security → Performance → Maintainability
   - Use comment prefixes (blocker/concern/suggestion/nit)

Step 4: TESTING REVIEW
   - Are tests present and meaningful?
   - Do they cover edge cases and error paths?
   - Would you trust these tests to catch a regression?

Step 5: VERDICT
   - Approve: All good, no blockers
   - Request Changes: Blockers identified, must address
   - Comment: Questions or suggestions, no blockers
```

## §5 Security Audit

**When**: Auditing code for vulnerabilities, compliance issues, or threat modeling.

```
Step 1: THREAT MODEL
   - Identify assets (data, credentials, access)
   - Map attack surfaces (API endpoints, user inputs, integrations)
   - Apply STRIDE: Spoofing, Tampering, Repudiation,
     Information Disclosure, Denial of Service, Elevation of Privilege

Step 2: STATIC ANALYSIS
   - Run SAST tools (Semgrep, SonarQube, CodeQL)
   - Check dependencies for CVEs (npm audit, pip-audit, trivy)
   - Review security-sensitive code paths manually

Step 3: DYNAMIC ANALYSIS
   - Run DAST tools against staging (OWASP ZAP, Burp)
   - Test authentication/authorization bypass attempts
   - Verify rate limiting and input validation

Step 4: REVIEW
   - OWASP Top 10 checklist (see references/security.md)
   - Secrets management audit
   - Encryption at rest and in transit
   - Logging and audit trail completeness

Step 5: REPORT
   - Document findings with severity ratings (Critical/High/Medium/Low)
   - Provide remediation steps for each finding
   - Create tracking tickets for remediation
   - Schedule re-audit after fixes
```

## §6 Performance Optimization

**When**: Investigating and resolving performance issues.

```
Step 1: MEASURE
   - Establish baseline metrics (latency, throughput, memory, CPU)
   - Identify performance goals (SLOs/SLAs)
   - Set up profiling tools appropriate to the stack

Step 2: PROFILE
   - CPU profiling: flame graphs, sampling profiler
   - Memory profiling: heap snapshots, allocation tracking
   - I/O profiling: network latency, disk I/O, DB query time
   - Frontend: Lighthouse, Web Vitals, bundle analyzer

Step 3: IDENTIFY BOTTLENECKS
   - Rank by impact (Amdahl's Law: optimize the biggest bottleneck)
   - Categorize: CPU-bound, I/O-bound, memory-bound
   - Check for classic issues:
     - N+1 queries
     - Missing indexes
     - Unnecessary serialization/deserialization
     - Unbounded caching
     - Synchronous I/O on hot paths

Step 4: OPTIMIZE
   - Fix ONE bottleneck at a time
   - Measure improvement after each change
   - Common fixes:
     - Add database indexes
     - Implement caching (with TTL and invalidation)
     - Batch/pipeline I/O operations
     - Use connection pooling
     - Lazy load / code split (frontend)
     - Switch to streaming for large payloads

Step 5: VERIFY
   - Re-run benchmarks against baseline
   - Load test at expected peak + 2x headroom
   - Verify no regression in correctness
   - Document optimizations and trade-offs
```

## §7 Migration Planning

**When**: Planning major version upgrades, framework migrations, or platform changes.

```
Step 1: ASSESS
   - Current state inventory (versions, dependencies, technical debt)
   - Target state definition (what and why)
   - Gap analysis (what needs to change)
   - Risk assessment (breaking changes, data migration, downtime)

Step 2: STRATEGY
   - Choose migration approach:
     - Big Bang: All at once (risky, fast)
     - Strangler Fig: Gradual replacement (safe, slower)
     - Parallel Run: Both systems simultaneously (expensive, safest)
   - Define rollback plan for each phase
   - Identify feature freeze windows

Step 3: PLAN
   - Break into phases with clear milestones
   - Identify dependencies between migration tasks
   - Create compatibility shims where needed
   - Plan data migration (ETL, schema changes, backfills)

Step 4: EXECUTE
   - Implement phase by phase
   - Verify each phase independently
   - Run dual-write / shadow traffic where possible
   - Monitor for regressions continuously

Step 5: VALIDATE
   - Functional testing of migrated components
   - Performance benchmarking (pre vs. post)
   - Data integrity verification
   - Remove old code and compatibility shims
```

## §8 Production Deployment

**When**: Deploying changes to production environments.

```
Step 1: PRE-DEPLOY
   - All CI checks pass on the release branch
   - Changelog/release notes prepared
   - Database migrations tested on staging
   - Feature flags configured for gradual rollout
   - Rollback procedure documented and tested
   - On-call team notified

Step 2: DEPLOY
   - Deploy to staging, run full test suite
   - Deploy to production using chosen strategy:
     - Blue-Green: Switch traffic to new deployment
     - Canary: Route small % of traffic, monitor
     - Rolling: Update instances incrementally
   - Monitor error rates, latency, and resource usage

Step 3: VERIFY
   - Run smoke tests against production
   - Check key user journeys work end-to-end
   - Verify monitoring dashboards and alerts
   - Confirm no increase in error rates

Step 4: POST-DEPLOY
   - Monitor for 30-60 minutes minimum
   - If issues detected: execute rollback immediately
   - Update deployment log and status page
   - Communicate release to stakeholders
```

## §9 Retrospective

**When**: After incidents, project completion, or periodic team review.

```
Step 1: GATHER DATA
   - Timeline of events (for incidents)
   - Metrics: velocity, defect rate, deployment frequency
   - Collect feedback from all participants
   - Review tickets, PRs, and documentation

Step 2: ANALYZE
   - What went well? (keep doing)
   - What went wrong? (stop doing / change)
   - What was confusing? (clarify / document)
   - For incidents: 5 Whys analysis to find root cause

Step 3: ACTION ITEMS
   - Concrete, assignable, measurable improvements
   - Prioritize by impact (not by ease)
   - Assign owners and deadlines
   - Examples:
     - "Add integration test for payment flow" (not "improve testing")
     - "Set up PagerDuty rotation" (not "improve on-call")

Step 4: FOLLOW UP
   - Track action items to completion
   - Review progress in next retrospective
   - Update processes and runbooks
   - Share learnings across teams
```
