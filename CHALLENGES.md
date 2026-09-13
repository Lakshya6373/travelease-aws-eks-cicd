# CHALLENGES.md — Build Challenges & Resolutions

Fill this in *as you actually build*, not in advance.
The sections below are pre-seeded with the challenges most likely to occur based on the architecture.
Replace the placeholder descriptions with what actually happened to you and how you resolved it.

---

## 1. IRSA Trust Policy `sub` Condition Typos

**What happened:**
<!-- e.g. The OIDC condition used "StringLike" instead of "StringEquals", or the sub claim had a typo in the namespace/service-account name. -->

**Symptom:**
<!-- e.g. Pod was started but AWS API calls returned AccessDenied, even though the role appeared to be attached. -->

**Resolution:**
<!-- e.g. Used `aws sts get-caller-identity` from inside the pod (`kubectl exec`) to verify which identity was actually being assumed. Found the condition was `system:serviceaccount:kube-system:aws-lb-controller` (wrong name). Fixed the Terraform `condition.values` to match the exact service account name used by the Helm chart. -->

---

## 2. ALB Controller Admission Webhook Race on Fresh Cluster

**What happened:**
<!-- e.g. First `helm upgrade --install travelease` run (right after bootstrap) failed with a webhook admission error. -->

**Symptom:**
<!-- e.g. `Error from server (InternalError): error when creating "ingress.yaml": Internal error occurred: failed calling webhook "ingress.alb.amazonaws.com"` -->

**Resolution:**
<!-- e.g. Added a 60-second sleep between the ALB controller helm install and the first app deploy in bootstrap-cluster.sh. Alternatively, re-ran the app helm install after confirming the ALB controller pods were Ready. -->

---

## 3. Testcontainers Docker Socket in CI

**What happened:**
<!-- e.g. Integration tests that work locally failed in GitHub Actions with "Cannot connect to the Docker daemon". -->

**Symptom:**
<!-- e.g. `org.testcontainers.shaded.com.github.dockerjava.api.exception.DockerClientException: Could not pull image` -->

**Resolution:**
<!-- e.g. GitHub-hosted ubuntu-latest runners do have Docker pre-installed, but the Docker daemon wasn't started at test time on a custom runner. Switched to the standard `ubuntu-latest` runner. Alternatively, added `docker info` as a pre-step to verify Docker availability. -->

---

## 4. ExternalSecret Propagation Delay on First Sync

**What happened:**
<!-- e.g. App pods crashed on first deploy with "db_host" environment variable empty. -->

**Symptom:**
<!-- e.g. Pod logs showed `IllegalArgumentException: DB_HOST must not be empty`. `kubectl get externalsecret -n travelease` showed status "SecretSyncedError". -->

**Resolution:**
<!-- e.g. The ClusterSecretStore was not yet ready when the ExternalSecret was created. Added a `kubectl wait` for the ClusterSecretStore to be established before the ExternalSecret apply in bootstrap-cluster.sh. Also confirmed the ESO IRSA role ARN was correct. -->

---

## 5. Bedrock `AccessDeniedException` Until Model Access Enabled

**What happened:**
<!-- e.g. Recommendation feature returned fallback results in all environments. -->

**Symptom:**
<!-- e.g. Application log: `software.amazon.awssdk.services.bedrockruntime.model.AccessDeniedException: You don't have access to the model with the specified model ID.` -->

**Resolution:**
<!-- e.g. Went to AWS Console → Amazon Bedrock → Model access in us-east-1 and requested/enabled access to Amazon Nova Micro. Access was granted within a few seconds. -->

---

## 6. Other Challenges

<!-- Add any other challenges encountered during the build here. -->

---

*This file is intentionally sparse at the start. Fill it in as you build — honest documentation of real problems and solutions is more valuable (and more credible to reviewers) than a pre-written list of hypothetical issues.*
