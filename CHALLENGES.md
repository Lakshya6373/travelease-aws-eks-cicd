# CHALLENGES.md — Build Challenges & Resolutions

This document records the actual challenges faced during the build, infrastructure deployment, and verification of TravelEase on AWS EKS, along with the technical root cause and permanent resolutions.

---

## 1. VPC Subnet Auto-Discovery Failure for AWS Load Balancer Controller

**What happened:**  
After deploying the Helm ingress resource, the AWS Load Balancer Controller failed to reconcile and could not create the ALB.

**Symptom:**  
Ingress resource stayed with an empty `ADDRESS` field (`kubectl get ingress -n travelease`).  
Controller logs showed:
```text
{"level":"error","msg":"Reconciler error","controller":"ingress","error":"couldn't auto-discover subnets: unable to resolve at least 2 subnets"}
```

**Root Cause:**  
The VPC Terraform module previously hardcoded the subnet tag as `"kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"` (which resolved to `kubernetes.io/cluster/dev-cluster`). However, the actual EKS cluster was named `travelease-dev`. Because the cluster name in the tag did not match, the controller ignored the subnets.

**Resolution:**  
1. Added a `cluster_name` variable to the VPC module (`terraform/modules/vpc/variables.tf`) and referenced it in public and private subnet tags (`"kubernetes.io/cluster/${var.cluster_name}" = "shared"`).
2. Passed `cluster_name = "travelease-${local.env}"` from the dev environment `main.tf`.
3. Applied the tag to the active subnets using AWS CLI so the controller immediately discovered them.

---

## 2. EKS Worker Nodes Missing RDS Security Group (CrashLoopBackOff)

**What happened:**  
The Spring Boot application pod failed to start on EKS and entered `CrashLoopBackOff` upon attempting to connect to PostgreSQL on RDS.

**Symptom:**  
Pod logs showed:
```text
org.postgresql.util.PSQLException: The connection attempt failed.
Caused by: java.net.SocketTimeoutException: Connect timed out
```

**Root Cause:**  
The managed EKS node group only had the auto-generated EKS cluster security group attached. The custom `node_sg` created by Terraform (which has ingress rules configured in RDS PostgreSQL security group on port 5432) was not attached to the worker node group instances.

**Resolution:**  
1. Updated `terraform/modules/eks/variables.tf` and `main.tf` to support `node_security_group_ids` on the `aws_eks_node_group.main` resource.
2. In `terraform/environments/dev/main.tf`, passed `node_security_group_ids = [module.security_groups.node_sg_id]` to the EKS module.

---

## 3. ALB Controller IAM Permission Missing for Listener Tagging & Attributes

**What happened:**  
After the subnets were tagged and the ALB was created, the controller crashed during listener creation and subsequent reconciliation cycles with `AccessDenied (403)`.

**Symptom:**  
1. Controller log:
```text
operation error Elastic Load Balancing v2: CreateListener, api error AccessDenied: User: ...assumed-role/dev-alb-controller-irsa is not authorized to perform: elasticloadbalancing:AddTags on resource: arn:aws:elasticloadbalancing:ap-south-1:892978057052:listener/app/...
```
2. After addressing AddTags, another error occurred:
```text
operation error Elastic Load Balancing v2: DescribeListenerAttributes, api error AccessDenied: User: ...assumed-role/dev-alb-controller-irsa is not authorized to perform: elasticloadbalancing:DescribeListenerAttributes because no identity-based policy allows the action
```

**Root Cause:**  
1. ELBv2 Listener ARN format has 3 path components after `listener/app/`: `listener/app/{lb-name}/{lb-id}/{listener-id}`. The policy only had two wildcards (`listener/app/*/*`), failing to match the third segment.
2. The IAM policy in `terraform/modules/irsa-alb-controller/iam_policy.json` was an older revision that lacked newer permissions required by AWS Load Balancer Controller `v3.5.0` (`DescribeListenerAttributes`, `DescribeTrustStores`, `DescribeCapacityReservation`, and EC2 describe actions like `GetSecurityGroupsForVpc`).

**Resolution:**  
1. Downloaded the official, up-to-date AWS Load Balancer Controller IAM policy specification.
2. Created Version 2 (`v2`) of `arn:aws:iam::892978057052:policy/dev-ALBControllerIAMPolicy` and marked it as the default version.
3. Updated `terraform/modules/irsa-alb-controller/iam_policy.json` with the complete official policy so Terraform and AWS stay in sync.
4. Performed a rollout restart on `deployment/aws-load-balancer-controller`. The controller immediately created the listener, registered the pod target as `healthy`, and populated the ingress address.

---

## 4. Helm Prometheus-Operator Webhook & Loki Configuration during Bootstrap

**What happened:**  
During fresh cluster bootstrapping via `scripts/bootstrap-cluster.sh`, Helm upgrades for `kube-prometheus-stack` and `loki-stack` hit TLS webhook admission timeouts and deprecated value keys.

**Symptom:**  
- Helm upgrade failed waiting for prometheus-operator admission webhook TLS cert secrets.
- `loki-stack` complained about deprecated `loki.datasource.isDefault` field.

**Resolution:**  
Updated `scripts/bootstrap-cluster.sh` to include `--set prometheusOperator.admissionWebhooks.enabled=false --set prometheusOperator.tls.enabled=false` and updated Loki config to `--set loki.isDefault=false`.

---

## 5. ExternalSecrets Operator & Database Credentials Sync

**What happened:**  
The application required database connection credentials (`DB_HOST`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`) synced from AWS Secrets Manager into a Kubernetes secret `travelease-db-secret`.

**Symptom:**  
Pods required valid secrets before Spring Boot could initialize Flyway migrations and JPA entity manager.

**Resolution:**  
Verified the ExternalSecret and ClusterSecretStore resources using IRSA. Once RDS security group access was established and secrets synced, Flyway migrations executed automatically, creating all schemas and seeding destination data.
