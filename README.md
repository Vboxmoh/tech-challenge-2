# Tech Challenge 2 — EKS, Docker, Terraform, Jenkins CI/CD

## Overview

This project deploys a Node.js web application to AWS EKS using a fully automated CI/CD pipeline with Jenkins. Infrastructure is provisioned using Terraform.

## Architecture
Developer → GitHub → Webhook → Jenkins (EC2)
↓
Docker Build
↓
Amazon ECR
↓
Helm Deploy to EKS
↓
User → ALB → EKS Cluster → Pod
## Stack

- **Application**: Node.js (Hello World)
- **Containerization**: Docker
- **Container Registry**: Amazon ECR
- **Orchestration**: AWS EKS (Kubernetes)
- **IaC**: Terraform
- **CI/CD**: Jenkins (Docker on EC2)
- **Package Manager**: Helm
- **Load Balancer**: AWS Application Load Balancer
- **Region**: eu-west-3 (Paris)

## Infrastructure Notes

> ⚠️ The TC2 specification requires t3.small nodes. This project uses t3.micro due to AWS account free-tier restrictions. The cluster was scaled progressively: 3 nodes initially for core infrastructure, then up to 7 nodes to accommodate Argo CD (which requires 7 additional pods). All functional requirements are fully met.

## Repository Structure
tech-challenge-2/
├── app/
│   ├── server.js          # Node.js Hello World app
│   └── Dockerfile         # Docker image definition
├── terraform/
│   ├── main.tf            # AWS provider
│   ├── vpc.tf             # VPC, subnets, IGW, route tables
│   ├── eks.tf             # EKS cluster, node group, ECR, IAM roles
│   ├── variables.tf       # Input variables
│   └── outputs.tf         # Output values
├── helm/
│   └── tc2-chart/
│       ├── Chart.yaml     # Helm chart metadata
│       ├── values.yaml    # Default values
│       └── templates/
│           ├── deployment.yaml   # Kubernetes Deployment
│           ├── service.yaml      # Kubernetes Service
│           ├── hpa.yaml          # Horizontal Pod Autoscaler
│           └── ingress.yaml      # ALB Ingress
├── jenkins/
│   └── terraform/
│       ├── main.tf        # Jenkins EC2 provisioning
│       ├── variables.tf
│       └── outputs.tf
└── Jenkinsfile            # CI/CD pipeline definition
## Prerequisites

- AWS CLI configured with terraform-admin credentials
- Terraform installed
- kubectl installed
- Helm installed
- Docker Desktop installed
- eksctl installed

## Deployment Steps

### 1. Clone the repository

```bash
git clone https://github.com/Vboxmoh/tech-challenge-2.git
cd tech-challenge-2
```

### 2. Run the app locally

```bash
cd app
node server.js
# Visit http://localhost:3000
```

### 3. Build and test Docker image locally

```bash
docker build -t tc2-app:local ./app
docker run --name tc2-test -p 3000:3000 tc2-app:local
# Visit http://localhost:3000
```

### 4. Provision EKS infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply
```

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-3 --name tc2-cluster
```

### 6. Install AWS Load Balancer Controller

```bash
eksctl utils associate-iam-oidc-provider --region eu-west-3 --cluster tc2-cluster --approve
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
eksctl create iamserviceaccount \
  --cluster=tc2-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=eu-west-3
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tc2-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-west-3 \
  --set vpcId=YOUR_VPC_ID
```

### 7. Deploy application with Helm

```bash
helm upgrade --install tc2-app ./helm/tc2-chart
```

### 8. Provision Jenkins server

```bash
cd jenkins/terraform
terraform init
terraform apply
```

## EKS Configuration

| Parameter | Value |
|---|---|
| Instance type | t3.micro (free-tier) |
| Nodes |	3 initially → scaled to 7 for Argo CD (min: 1, max: 7) |
| HPA min pods | 1 |
| HPA max pods | 3 |
| HPA CPU trigger | 50% |
| HPA Memory trigger | 50% |

## Jenkins Pipeline

The pipeline runs automatically on every push to the `main` branch via GitHub webhook.

**Stages:**
1. **Checkout** — pulls the latest code from GitHub
2. **Build Docker Image** — builds the image with the build number as tag
3. **Push to ECR** — authenticates to ECR and pushes the image
4. **Deploy to EKS** — runs `helm upgrade --install` to deploy the new image

## Application URL

The application is accessible via the AWS ALB:
http://k8s-default-tc2chart-8a65e9b496-2001218732.eu-west-3.elb.amazonaws.com/
## Destroy Infrastructure

```bash
# Destroy EKS infrastructure
cd terraform
terraform destroy

# Destroy Jenkins server
cd jenkins/terraform
terraform destroy
```
## Bonus — GitOps with GitHub Actions & Argo CD

The `gitops` branch implements a GitOps-style CI/CD workflow as an alternative to Jenkins.

### Architecture
Push code to gitops branch
↓
GitHub Actions — Build Docker image + Push to ECR + Update values.yaml
↓
Argo CD detects change in values.yaml
↓
Argo CD automatically redeploys to EKS
### GitHub Actions (CI)

The workflow `.github/workflows/ci.yml` is triggered on every push to the `gitops` branch:
1. Builds the Docker image
2. Pushes it to Amazon ECR with the commit SHA as tag
3. Updates `helm/tc2-chart/values.yaml` with the new image tag

### Argo CD (CD)

Argo CD is installed in the EKS cluster and watches the `gitops` branch. It automatically syncs the cluster state with the Helm chart whenever `values.yaml` changes.

### Infrastructure Notes for GitOps

> ⚠️ Due to t3.micro pod limits (4 pods per node), 7 nodes were required to run all system pods + Argo CD (7 pods) + the application. The CRD `applicationsets.argoproj.io` required server-side apply due to annotation size limits (`--server-side` flag).

### Argo CD Access

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit https://localhost:8080
# Username: admin
# Password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### GitOps Demo

The application serves `Hello from GitOps!` when deployed from the `gitops` branch, demonstrating end-to-end GitOps reconciliation.
## Troubleshooting & Technical Challenges

### 1. ECR login failing in PowerShell
**Problem:** `aws ecr get-login-password | docker login` returned error 400 in PowerShell.  
**Cause:** PowerShell pipe does not handle binary output correctly on Windows.  
**Solution:** Use Git Bash for all commands involving pipes (`|`).

### 2. t3.micro pod limit (4 pods per node)
**Problem:** AWS Load Balancer Controller pods were stuck in `Pending` state.  
**Cause:** t3.micro instances support a maximum of 4 pods per node due to ENI limitations. All 4 slots were already occupied by system pods (aws-node, coredns x2, kube-proxy).  
**Solution:** Added additional nodes to the cluster. Prefix delegation (`ENABLE_PREFIX_DELEGATION=true`) was attempted but is not supported on t3.micro due to single ENI limitations.

### 3. Jenkins Docker socket permission denied
**Problem:** Jenkins pipeline failed with `permission denied while trying to connect to the Docker daemon socket`.  
**Cause:** The `jenkins` user inside the container did not have access to `/var/run/docker.sock`.  
**Solution:** `chmod 666 /var/run/docker.sock` inside the Jenkins container.

### 4. Jenkins EC2 IP changes on reboot
**Problem:** Jenkins URL changed after every EC2 stop/start cycle.  
**Cause:** Public IP is dynamically assigned by AWS on each start.  
**Solution:** Updated the GitHub webhook URL after each restart. An Elastic IP could be attached to avoid this permanently.

### 5. jenkins-ci-user not authorized on EKS
**Problem:** `kubectl get nodes` inside Jenkins returned `Unauthorized` error.  
**Cause:** `jenkins-ci-user` was not listed in the EKS `aws-auth` ConfigMap.  
**Solution:** Added `jenkins-ci-user` to `aws-auth` ConfigMap with `system:masters` group.

### 6. Argo CD CRD too large
**Problem:** `kubectl apply` failed with `metadata.annotations: Too long: may not be more than 262144 bytes` when installing Argo CD.  
**Cause:** The `ApplicationSet` CRD annotations exceed the kubectl client-side apply limit.  
**Solution:** Used server-side apply: `kubectl apply --server-side -f ...`

### 7. Argo CD pods Pending due to t3.micro pod limits
**Problem:** Argo CD requires 7 pods minimum — combined with system pods and the application, the cluster ran out of pod slots.  
**Cause:** t3.micro supports only 4 pods per node.  
**Solution:** Scaled the node group progressively from 3 to 7 nodes to accommodate all pods.

### 8. GitHub Actions permission denied when pushing to repo
**Problem:** GitHub Actions failed with `remote: Permission to Vboxmoh/tech-challenge-2.git denied to github-actions[bot]`.  
**Cause:** Default workflow permissions are read-only.  
**Solution:** Enabled **Read and write permissions** under Settings → Actions → General → Workflow permissions.
