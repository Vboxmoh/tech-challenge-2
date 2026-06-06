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

> ⚠️ The TC2 specification requires t3.small nodes. This project uses t3.micro due to AWS account free-tier restrictions. As a result, 3 nodes are required instead of 1 to accommodate the system pods and application pods (t3.micro supports a maximum of 4 pods per node). All other requirements are fully met.

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
| Nodes | 3 (min: 1, max: 4) |
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
