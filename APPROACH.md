# APPROACH.md — Architecture Decision Record

This document explains every significant design decision made while building TravelEase, with alternatives considered and the reasoning behind each choice.

---

## 1. Three Separate EKS Clusters vs. Namespace-per-Environment

**Decision:** Three completely separate EKS clusters — one per environment (dev/test/prod).

**Alternatives considered:**
- Single cluster with namespace isolation (dev/test/prod namespaces)
- Two clusters (shared dev+test, separate prod)

**Why this one:**
A single cluster with namespace isolation is operationally simpler but provides weaker blast-radius isolation: a misconfigured ClusterRole, a runaway node process, or even a Kubernetes control-plane bug affects all environments simultaneously. Separate clusters mean a dev deployment gone wrong cannot impact production in any way — no shared RBAC, no shared node pools, no shared Ingress controller. For a project explicitly graded on production-readiness, this is the right default. The cost difference (3× control planes = ~$7.20/day) is real but acceptable given the same-day destroy discipline.

---

## 2. Loki + Promtail vs. ELK Stack

**Decision:** Loki + Promtail for log aggregation, surfaced via Grafana.

**Alternatives considered:**
- Elasticsearch + Logstash + Kibana (ELK)
- CloudWatch Container Insights
- Datadog

**Why this one:**
Loki has a dramatically smaller resource footprint than ELK — it indexes labels, not full text, making it 10× cheaper to run on small nodes. It integrates natively with Grafana, which we already run for metrics, giving us one UI for everything. CloudWatch Container Insights would work but creates a hard AWS lock-in and separates logs from metrics into different consoles. For demo-scale clusters that get destroyed same-day, Loki's simplicity wins.

---

## 3. GitHub Environments + Required Reviewers vs. Custom Approval Webhook

**Decision:** GitHub native "Required reviewers" on the `production` environment.

**Alternatives considered:**
- Atlantis for GitOps-style Terraform approval
- Custom webhook (Slack button → Lambda → resume pipeline)
- ArgoCD with sync policies

**Why this one:**
GitHub Environments required reviewers require zero additional infrastructure, send email notifications automatically, integrate directly into the PR/commit UI, and are already available on free/team accounts. The reviewer sees the full pipeline context (test results, Trivy scan, smoke test) via the step summary posted before the approval gate. A custom Slack webhook adds a Lambda, a Slack app, and IAM plumbing for no meaningful gain at this scale.

---

## 4. S3-Native Locking vs. DynamoDB State Locking

**Decision:** Terraform `use_lockfile = true` (S3-native locking, Terraform ≥ 1.11).

**Alternatives considered:**
- DynamoDB table for state locking (the traditional approach)

**Why this one:**
Terraform 1.11 added native S3 locking using conditional writes — no DynamoDB table required. This eliminates one resource, one IAM policy, and one more service to manage. The `use_lockfile = true` flag is a one-line addition to each `backend "s3"` block. Since the assignment specifies Terraform ≥ 1.11, there is no reason to use DynamoDB.

---

## 5. Amazon Nova Micro + DB-Grounded Results vs. Larger Bedrock Model or Full RAG

**Decision:** Single call to Nova Micro — classify the query into categories, then query real destination rows from PostgreSQL.

**Alternatives considered:**
- Claude Haiku/Sonnet for richer natural-language responses
- Full RAG with a vector store (OpenSearch or Bedrock Knowledge Bases)
- Storing embeddings per destination and doing similarity search

**Why this one:**
The recommendation feature is a search-assist, not a knowledge-base Q&A. The only "knowledge" needed is which of 7 category labels matches the user's intent — Nova Micro is more than capable of this single-label classification task. By returning real DB rows rather than model-invented place names, we guarantee factual accuracy and avoid hallucination entirely. Full RAG would add OpenSearch or Bedrock Knowledge Bases to the cost and complexity for no observable quality improvement given the small, fixed destination catalog.

---

## 6. WAF Managed Rule Groups vs. Shield Advanced

**Decision:** WAFv2 with 3 AWS Managed Rule Groups + 1 custom rate-based rule.

**Alternatives considered:**
- AWS Shield Advanced (~$3,000/month)
- No WAF (just security groups)

**Why this one:**
Shield Advanced is enterprise-grade DDoS protection at an enterprise price — completely disproportionate for a demo project. WAFv2 managed rule groups cover the OWASP Top 10 (SQLi, common exploits, known bad inputs) at ~$0.30/day. The custom rate-based rule prevents trivial flood attacks. This is a realistic, proportionate choice that a real startup would make. Shield Standard (automatic on all ALBs) handles volumetric DDoS for free.

---

## 7. Single-AZ RDS vs. Multi-AZ

**Decision:** Single-AZ RDS across all environments.

**Alternatives considered:**
- Multi-AZ for prod (automatic failover, ~2× cost)
- Aurora Serverless (pay-per-query)

**Why this one:**
Multi-AZ doubles the RDS cost (~$0.70/day → ~$1.40/day for db.t3.micro), and for a demo project that gets destroyed same-day, this is not justified. In a real production deployment, Multi-AZ on prod would be non-negotiable — automatic failover means ~60 seconds of downtime vs. 15–20 minutes for a manual restore. This is explicitly called out as a **documented cost vs. production-realism trade-off** and would be the first thing to change before accepting real traffic.

---

## 8. Consolidated Regional Strategy: All Services and Bedrock in ap-south-1

**Decision:** All infrastructure (EKS, RDS, ALB, WAF, VPC) and Bedrock invocations in `ap-south-1` (Mumbai).

**Alternatives considered:**
- Split region: infrastructure in `ap-south-1`, Bedrock calls routed to `us-east-1`
- Multi-region active-active deployment

**Why this one:**
Consolidating all traffic and services into `ap-south-1` keeps data residency local and eliminates cross-continent latency hops (~200ms round trips between Mumbai and N. Virginia). Amazon Nova Micro is available in `ap-south-1` via the APAC regional inference profile (`apac.amazon.nova-micro-v1:0`). This automatically and transparently routes invocations across low-latency Asia Pacific regions (Mumbai, Tokyo, Sydney, Seoul) while keeping the caller entirely within `ap-south-1`.

---

## 9. Centralized Logging via Three Different Backends, One Grafana UI

**Decision:** Application + system logs in Loki; ALB access logs in S3 → Glue/Athena. Grafana aggregates all three.

**Alternatives considered:**
- Forwarding ALB logs to Loki (requires a Fluentd/Vector forwarder running as a pod, which introduces more complexity than Athena)
- CloudWatch for all logs (vendor lock-in, separate UI, costs more at volume)
- Ignoring access logs or system logs entirely (would not satisfy "centralized logging" requirement)

**Why this one:**
ALB is a managed AWS service — it cannot push directly to Loki. The AWS-native path is S3 delivery (enabled via a single Ingress annotation). Rather than adding a log-forwarding sidecar, we use Grafana's official Athena datasource plugin to query the S3 bucket directly through a Glue catalog table. This keeps one Grafana dashboard as the single pane of glass for application logs (Loki), node/system logs (Loki via journal scrape), and HTTP access logs (Athena) — which is the correct answer to "centralized logging" even when the storage backends differ.

---

## 10. Direct Pod IRSA Secrets Fetching vs. External Secrets Operator (ESO)

**Decision:** The application pod uses its own IAM Role for Service Accounts (IRSA) to fetch credentials directly from AWS Secrets Manager at startup via `SecretsEnvironmentPostProcessor`.

**Alternatives considered:**
- External Secrets Operator (ESO) syncing AWS Secrets Manager to Kubernetes `Secret` objects
- CSI Secrets Store Driver
- Hardcoding or passing secrets via CI/CD environment variables

**Why this one:**
Running the External Secrets Operator requires maintaining extra custom resource definitions (`ClusterSecretStore`, `ExternalSecret`), a dedicated controller deployment, its own IRSA role, and a continuous synchronization loop. Since the application pod already requires an IRSA identity for Amazon Bedrock AI, extending that role to read its environment-scoped secret (`travelease/${env}/app-secrets`) removes an entire third-party cluster operator dependency. At startup, the Spring Boot `SecretsEnvironmentPostProcessor` pulls the database credentials before `DataSourceAutoConfiguration` starts, while still gracefully falling back to local defaults for test and local development.
