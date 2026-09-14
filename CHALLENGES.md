# CHALLENGES.md — Build Challenges, Diagnosis & Technical Resolutions

This document is a comprehensive engineering log of **all real challenges** encountered from Day 0 setup through Day 1 production verification on AWS EKS, including how each issue was diagnosed (symptoms, logs, commands) and the exact technical resolution applied.

---

## Table of Contents
1. [Terraform WAF Module Single-Line Block Syntax Error](#1-terraform-waf-module-single-line-block-syntax-error)
2. [Single t3.small Worker Node Memory Exhaustion](#2-single-t3small-worker-node-memory-exhaustion)
3. [Windows Carriage Return (`\r`) in Bash Scripts Corrupting Helm Variables](#3-windows-carriage-return-r-in-bash-scripts-corrupting-helm-variables)
4. [Prometheus Operator Admission Webhook TLS Timeout & Duplicate Default Datasource](#4-prometheus-operator-admission-webhook-tls-timeout--duplicate-default-datasource)
5. [External Secrets API Version Deprecation (`v1beta1` → `v1`)](#5-external-secrets-api-version-deprecation-v1beta1--v1)
6. [Terraform Destroy Hang on Subnet Deletion Due to Orphaned Kubernetes ENIs](#6-terraform-destroy-hang-on-subnet-deletion-due-to-orphaned-kubernetes-enis)
7. [VPC Subnet Auto-Discovery Failure for AWS Load Balancer Controller](#7-vpc-subnet-auto-discovery-failure-for-aws-load-balancer-controller)
8. [EKS Worker Nodes Missing RDS Security Group (Database Connection Timeout)](#8-eks-worker-nodes-missing-rds-security-group-database-connection-timeout)
9. [ALB Controller IAM Permission Missing for Listener Tagging (`AddTags`)](#9-alb-controller-iam-permission-missing-for-listener-tagging-addtags)
10. [ALB Controller IAM Permission Missing for `DescribeListenerAttributes`](#10-alb-controller-iam-permission-missing-for-describelistenerattributes)

---

## 1. Terraform WAF Module Single-Line Block Syntax Error

### What Happened
During initial `terraform init` / `terraform plan` for the `dev` environment, Terraform failed to parse the WAF module.

### Symptoms & Logs
```text
Error: Argument definition required
  on ../../modules/waf/main.tf line 15, in resource "aws_wafv2_web_acl" "main":
  15:     override_action { none {} }

A single-line block definition can contain only a single argument.
If you meant to define argument "none", use an equals sign to assign it a value.
To define a nested block, place it on a line of its own within its parent block.
```

### How We Identified It
Examining lines 15, 33, and 51 of `terraform/modules/waf/main.tf` showed nested blocks written on a single line (`override_action { none {} }`). Terraform HCL grammar requires nested blocks to be placed on their own lines.

### Resolution
Reformatted all `override_action` blocks into multi-line syntax in [terraform/modules/waf/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/waf/main.tf):
```hcl
override_action {
  none {}
}
```

---

## 2. Single t3.small Worker Node Memory Exhaustion

### What Happened
The initial dev configuration had `node_desired_size = 1` using a `t3.small` instance (2 vCPU, 2GB RAM, with ~1.6GB allocatable memory). Deploying the monitoring stack (`kube-prometheus-stack`, `loki-stack`), platform controllers, and the Spring Boot application would overwhelm the single node, causing pods to remain in `Pending` state due to `Insufficient memory`.

### Symptoms & Logs
- Single node memory allocatable was ~1.6GB.
- Default Prometheus server memory request is 1GB+, leaving no memory for Grafana, Loki, Metrics Server, External Secrets, and Spring Boot (which requires 512MB+).

### How We Identified It
Reviewed `dev/terraform.tfvars` against the resource requests in `platform/grafana-values-common.yaml` and standard Helm charts before bootstrapping.

### Resolution
1. Updated [terraform/environments/dev/terraform.tfvars](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/environments/dev/terraform.tfvars) to set `node_desired_size = 2` (within `node_max_size = 2`).
2. This scaled the worker node group across two Availability Zones (`ap-south-1a`, `ap-south-1b`), providing ~3.4GB allocatable memory and multi-AZ fault tolerance.

---

## 3. Windows Carriage Return (`\r`) in Bash Scripts Corrupting Helm Variables

### What Happened
When running `scripts/bootstrap-cluster.sh` inside Git Bash on Windows, Helm commands and annotations failed with syntax and formatting errors.

### Symptoms & Logs
Variables extracted via `terraform output -raw` (such as `ALB_ROLE_ARN` and `ESO_ROLE_ARN`) contained invisible carriage returns (`\r`), resulting in malformed IAM role ARNs in Helm `--set` arguments:
```text
Error: ... role-arn "arn:aws:iam::892978057052:role/dev-alb-controller-irsa\r" is invalid
```

### How We Identified It
Inspected variable extraction in bash under Windows Git Bash where standard output pipes retain CRLF line endings from native Windows binaries.

### Resolution
Piped all raw Terraform and AWS CLI output values through `tr -d '\r'` in [scripts/bootstrap-cluster.sh](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/scripts/bootstrap-cluster.sh):
```bash
ALB_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw alb_controller_role_arn | tr -d '\r')
ESO_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw eso_role_arn | tr -d '\r')
VPC_ID=$(terraform -chdir="$TF_DIR" output -raw vpc_id 2>/dev/null | tr -d '\r' || echo "")
```

---

## 4. Prometheus Operator Admission Webhook TLS Timeout & Duplicate Default Datasource

### What Happened
During cluster bootstrap via Helm:
1. `kube-prometheus-stack` timed out waiting for admission webhook TLS certificates.
2. The Grafana pod crashed continuously with a datasource configuration error.

### Symptoms & Logs
1. Helm error:
   ```text
   Internal error occurred: failed calling webhook "prometheusrulemutate.monitoring.coreos.com": Post "...": context deadline exceeded
   ```
2. Grafana pod log:
   ```text
   Datasource provisioning error: datasource.yaml config is invalid. Only one datasource per organization can be marked as default
   ```

### How We Identified It
- `kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana` revealed that both Prometheus and Loki Helm charts had configured their respective datasources as `isDefault: true`.
- Inspected webhook TLS generation behavior in dev environments where cert-manager is omitted.

### Resolution
1. Disabled the admission webhook and webhook TLS in [scripts/bootstrap-cluster.sh](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/scripts/bootstrap-cluster.sh):
   ```bash
   --set prometheusOperator.admissionWebhooks.enabled=false \
   --set prometheusOperator.tls.enabled=false
   ```
2. Fixed Loki datasource setting in `scripts/bootstrap-cluster.sh`:
   ```bash
   --set loki.isDefault=false
   ```
3. Ensured only Prometheus is marked default in `platform/grafana-values-common.yaml`.

---

## 5. External Secrets API Version Deprecation (`v1beta1` → `v1`)

### What Happened
Applying `platform/cluster-secret-store.yaml` and `helm/travelease/templates/externalsecret.yaml` triggered API version mismatch errors against the newly installed External Secrets Operator chart.

### Symptoms & Logs
```text
error: unable to recognize "platform/cluster-secret-store.yaml": no matches for kind "ClusterSecretStore" in version "external-secrets.io/v1beta1"
```

### How We Identified It
Checked the installed CRD versions (`kubectl get crds | grep external-secrets`) and saw that modern ESO releases had promoted the API to `v1`.

### Resolution
Updated `apiVersion` in both `platform/cluster-secret-store.yaml` and `helm/travelease/templates/externalsecret.yaml` from `external-secrets.io/v1beta1` to `external-secrets.io/v1`.

---

## 6. Terraform Destroy Hang on Subnet Deletion Due to Orphaned Kubernetes ENIs

### What Happened
When tearing down infrastructure overnight via `terraform destroy -auto-approve`, the command stalled for over 17 minutes trying to delete `module.vpc.aws_subnet.private[1]`.

### Symptoms & Logs
```text
module.vpc.aws_subnet.private[1]: Still destroying... [id=subnet-01a7015aaf78386c8, 17m50s elapsed]
```

### How We Identified It
Ran AWS CLI to inspect why AWS was refusing to delete the subnet:
```bash
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-01a7015aaf78386c8" \
  --query "NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]" \
  --output table --region ap-south-1
```
Output revealed an orphaned Elastic Network Interface (`eni-059b64ebdfc27a719`, description `aws-K8S-i-038cccb8c1a399ee3`) created by the Kubernetes VPC CNI that AWS had not detached before the node was terminated.

### Resolution
Wrote an automated shell loop to force-detach and delete all leftover ENIs in the subnet:
```bash
for ENI in $(aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-01a7015aaf78386c8" \
  --query "NetworkInterfaces[*].NetworkInterfaceId" \
  --output text --region ap-south-1); do
    echo "Deleting ENI: $ENI"
    ATTACHMENT=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text --region ap-south-1 2>/dev/null)
    if [ "$ATTACHMENT" != "None" ] && [ ! -z "$ATTACHMENT" ]; then
      aws ec2 detach-network-interface --attachment-id $ATTACHMENT --force --region ap-south-1 2>/dev/null || true
      sleep 3
    fi
    aws ec2 delete-network-interface --network-interface-id $ENI --region ap-south-1 2>/dev/null || true
done
```
The Terraform destroy process immediately unblocked and finished within seconds.

---

## 7. VPC Subnet Auto-Discovery Failure for AWS Load Balancer Controller

### What Happened
After deploying the TravelEase Helm chart, the Ingress resource remained without an external address.

### Symptoms & Logs
1. `kubectl get ingress -n travelease` showed `ADDRESS` column was completely empty for 30+ minutes.
2. `kubectl logs -n kube-system deployment/aws-load-balancer-controller` showed:
   ```text
   {"level":"error","msg":"Reconciler error","controller":"ingress","error":"couldn't auto-discover subnets: unable to resolve at least 2 subnets"}
   ```

### How We Identified It
1. Checked subnet tags in the VPC module ([terraform/modules/vpc/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/vpc/main.tf)):
   ```hcl
   "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
   ```
2. When `var.environment_name = "dev"`, this evaluated to `kubernetes.io/cluster/dev-cluster`.
3. However, the EKS cluster was named **`travelease-dev`**! Because the tag key did not match the cluster name, the ALB controller ignored the subnets.

### Resolution
1. Added `cluster_name` variable to [terraform/modules/vpc/variables.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/vpc/variables.tf).
2. Updated [terraform/modules/vpc/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/vpc/main.tf) to tag subnets with `"kubernetes.io/cluster/${var.cluster_name}" = "shared"`.
3. Passed `cluster_name = "travelease-${local.env}"` from [terraform/environments/dev/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/environments/dev/main.tf).
4. Tagged active subnets immediately via AWS CLI so the controller could proceed without waiting for a re-apply:
   ```bash
   aws ec2 create-tags --resources $SUBNET --tags Key="kubernetes.io/cluster/travelease-dev",Value="shared" --region ap-south-1
   ```

---

## 8. EKS Worker Nodes Missing RDS Security Group (Database Connection Timeout)

### What Happened
The application pod entered `CrashLoopBackOff` upon startup and failed readiness checks.

### Symptoms & Logs
Pod logs (`kubectl logs -n travelease deployment/travelease`):
```text
org.flywaydb.core.internal.exception.FlywaySqlException: Unable to obtain connection from database: The connection attempt failed.
Caused by: org.postgresql.util.PSQLException: The connection attempt failed.
Caused by: java.net.SocketTimeoutException: Connect timed out
```

### How We Identified It
1. Decoded the Kubernetes secret (`kubectl get secret travelease-db-secret -n travelease -o jsonpath='{.data}'`) and verified that `db_host`, `db_user`, `db_password`, and `db_port` exactly matched the live RDS instance.
2. Verified that `dev-rds-sg` allowed port 5432 from `dev-node-sg`.
3. Inspected [terraform/modules/eks/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/eks/main.tf) lines 73-97 (`aws_eks_node_group.main`): **no custom security groups were assigned**.
4. EKS nodes were only attached to the auto-generated EKS cluster security group (`eks-cluster-sg-travelease-dev-*`). Because the nodes lacked `dev-node-sg`, RDS rejected all incoming packets on port 5432.

### Resolution
1. Authorized the VPC CIDR (`10.10.0.0/16`) on port 5432 in `dev-rds-sg` via AWS CLI for immediate connectivity:
   ```bash
   aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 5432 --cidr 10.10.0.0/16 --region ap-south-1
   ```
2. In Terraform, added `node_security_group_ids` to [terraform/modules/eks/variables.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/eks/variables.tf) and [terraform/modules/eks/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/eks/main.tf).
3. Passed `node_security_group_ids = [module.security_groups.node_sg_id]` in [terraform/environments/dev/main.tf](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/environments/dev/main.tf).
4. The Spring Boot application immediately connected to RDS PostgreSQL, ran Flyway database migrations, and transitioned to `1/1 Running`.

---

## 9. ALB Controller IAM Permission Missing for Listener Tagging (`AddTags`)

### What Happened
Once subnets were discovered, the ALB was created, but the controller failed when configuring the HTTP port 80 listener.

### Symptoms & Logs
Controller log:
```text
operation error Elastic Load Balancing v2: CreateListener, https response error StatusCode: 403, 
api error AccessDenied: User: arn:aws:sts::892978057052:assumed-role/dev-alb-controller-irsa/... is not authorized to perform: 
elasticloadbalancing:AddTags on resource: arn:aws:elasticloadbalancing:ap-south-1:892978057052:listener/app/k8s-travelea-travelea-a5bbc7df32/bed5b4727a54e7ce/*
```

### How We Identified It
Examined the resource ARN in the error:
`listener/app/{lb-name}/{lb-id}/{listener-id}`
The ARN has **3 path components** after `listener/app/`. The existing IAM policy in `iam_policy.json` only had **2 wildcards** (`arn:aws:elasticloadbalancing:*:*:listener/app/*/*`), failing to match the listener ID segment.

### Resolution
Updated the ARN resource patterns to use 3 path wildcards:
```json
"arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
"arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
"arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
"arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*"
```

---

## 10. ALB Controller IAM Permission Missing for `DescribeListenerAttributes`

### What Happened
After fixing the `AddTags` wildcard pattern, restarting the controller resulted in another `403 AccessDenied` error on listener attributes reconciliation.

### Symptoms & Logs
Controller log:
```text
operation error Elastic Load Balancing v2: DescribeListenerAttributes, https response error StatusCode: 403, 
api error AccessDenied: User: arn:aws:sts::892978057052:assumed-role/dev-alb-controller-irsa/... is not authorized to perform: 
elasticloadbalancing:DescribeListenerAttributes because no identity-based policy allows the elasticloadbalancing:DescribeListenerAttributes action
```

### How We Identified It
1. The installed controller version is `v3.5.0` (`v2.8+` core).
2. The IAM policy in `terraform/modules/irsa-alb-controller/iam_policy.json` was an outdated revision that lacked modern ELBv2 actions:
   - `elasticloadbalancing:DescribeListenerAttributes`
   - `elasticloadbalancing:DescribeTrustStores`
   - `elasticloadbalancing:DescribeCapacityReservation`
   - `ec2:GetSecurityGroupsForVpc`, `ec2:DescribeRouteTables`, `ec2:DescribeIpamPools`

### Resolution
1. Downloaded the official, up-to-date IAM policy specification directly from AWS (`kubernetes-sigs/aws-load-balancer-controller`).
2. Created Version 2 (`v2`) of `arn:aws:iam::892978057052:policy/dev-ALBControllerIAMPolicy` and set it as the default version in AWS IAM:
   ```bash
   aws iam create-policy-version \
     --policy-arn arn:aws:iam::892978057052:policy/dev-ALBControllerIAMPolicy \
     --policy-document file://official_iam_policy.json \
     --set-as-default --region ap-south-1
   ```
3. Replaced [terraform/modules/irsa-alb-controller/iam_policy.json](file:///d:/lakshya/Project1.0/travelease-aws-eks-cicd/terraform/modules/irsa-alb-controller/iam_policy.json) with the complete policy so Terraform and AWS remain in 100% sync.
4. Cleaned up the temporary inline policy `alb-listener-addtags`.
5. Restarted the controller:
   ```bash
   kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
   ```
6. **Result:** The controller reconciled with 0 errors, created the listener, registered the pod as `healthy`, and populated the Ingress address:
   `k8s-travelea-travelea-a5bbc7df32-795130883.ap-south-1.elb.amazonaws.com`
