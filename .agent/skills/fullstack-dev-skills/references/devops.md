# DevOps & Reliability

CI/CD pipelines, containerization, deployment strategies, and site reliability.

## CI/CD Pipeline (GitHub Actions)

```yaml
name: CI
on:
  push:
    branches: [main]
jobs:
  build-test-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .
      - name: Run tests
        run: docker run --rm myapp:${{ github.sha }} pytest
      - name: Scan image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
      - name: Push to registry
        run: |
          docker tag myapp:${{ github.sha }} ghcr.io/org/myapp:${{ github.sha }}
          docker push ghcr.io/org/myapp:${{ github.sha }}
```

## Docker Best Practices

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY . .
USER nonroot
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:8080/health || exit 1
CMD ["python", "main.py"]
```

## Deployment Strategies

| Strategy | Risk | Rollback | Use When |
|----------|------|----------|----------|
| Rolling | Medium | Slow | Standard updates |
| Blue-Green | Low | Instant | Zero-downtime required |
| Canary | Low | Fast | Risky changes, gradual rollout |
| Recreate | High | Slow | Dev/staging only |

## Kubernetes Essentials

| Resource | Purpose |
|----------|---------|
| Deployment | Stateless workloads, rolling updates |
| StatefulSet | Databases, stateful apps |
| Service | Internal networking, load balancing |
| Ingress | External traffic routing |
| ConfigMap/Secret | Configuration and secrets |
| HPA | Horizontal auto-scaling |

## Terraform / IaC

| Practice | Detail |
|----------|--------|
| State | Remote backend (S3, GCS) with locking |
| Modules | Reusable, versioned modules |
| Plan | Always `terraform plan` before apply |
| Secrets | Never in .tf files; use vault or env vars |

## SRE Practices

| Concept | Purpose |
|---------|---------|
| SLO/SLA | Define reliability targets |
| Error Budget | Balance velocity vs reliability |
| Incident Response | Detect → Triage → Mitigate → RCA → Prevent |
| Postmortem | Blameless, actionable, shared |

## Rollback Procedure

```bash
kubectl rollout undo deployment/myapp -n production
kubectl rollout status deployment/myapp -n production
curl -f https://myapp.example.com/health
```

## Rules

### Always
- Infrastructure as code (never manual changes)
- Health checks and readiness probes
- Container scanning in CI/CD
- Document rollback procedures
- GitOps for Kubernetes (ArgoCD, Flux)

### Never
- Deploy without staging verification
- Store secrets in code or CI variables
- Use `latest` tag in production
- Skip resource limits in containers
- Deploy on Friday without monitoring
