# Infrastructure & Cloud

Container orchestration, IaC, and cloud architecture patterns.

## Kubernetes Architecture

| Component | Role |
|-----------|------|
| Control Plane | API server, scheduler, controller manager, etcd |
| Worker Nodes | kubelet, kube-proxy, container runtime |
| Pods | Smallest deployable unit |
| Services | Stable networking and load balancing |
| Ingress | HTTP/HTTPS routing |

### Key Patterns
- **Liveness Probe**: Restart unhealthy containers
- **Readiness Probe**: Remove from load balancer when not ready
- **Resource Limits**: Always set CPU/memory requests and limits
- **PodDisruptionBudget**: Ensure availability during maintenance
- **NetworkPolicy**: Restrict pod-to-pod communication

## Terraform Best Practices

```hcl
terraform {
  required_version = ">= 1.5"
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

resource "aws_ecs_service" "app" {
  name            = "myapp"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 3

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
```

## Cloud Architecture Patterns

| Pattern | Use Case |
|---------|----------|
| Multi-AZ | High availability within a region |
| Multi-Region | Disaster recovery, global users |
| Serverless | Event-driven, variable workloads |
| Edge Computing | Low latency, content delivery |

## Database Selection

| Type | Best For | Examples |
|------|----------|----------|
| Relational | Transactions, complex queries | PostgreSQL, MySQL |
| Document | Flexible schema, hierarchical data | MongoDB, DynamoDB |
| Key-Value | Caching, sessions | Redis, Memcached |
| Graph | Relationship-heavy queries | Neo4j, Neptune |
| Time-Series | Metrics, IoT data | TimescaleDB, InfluxDB |
| Vector | AI embeddings, similarity search | Pinecone, pgvector |
