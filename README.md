# EKS GitLab Infrastructure

Infrastructure as Code for deploying a self-hosted GitLab instance on Amazon EKS.

## Description

This repository contains Terraform modules and Helm configurations to deploy GitLab on AWS EKS. The setup includes:

- **EKS Cluster**: Single-node Kubernetes cluster (t3a.large)
- **GitLab**: Deployed via Helm chart v9.0.0
- **PostgreSQL**: Official postgres:16-alpine image
- **NGINX Ingress**: NodePort service for ALB integration
- **Storage**: EBS volumes for persistent data

The infrastructure is designed for cost-effective, single-node deployments with HTTP-only access through an Application Load Balancer.

## Prerequisites

- Terraform >= 1.0
- kubectl >= 1.27
- AWS CLI >= 2.0
- Helm >= 3.0
- AWS account with EKS permissions
- Existing VPC with subnets
- Configured AWS credentials

## Usage

### 1. Deploy EKS Cluster

```bash
cd eks
terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name test-eks-cluster --region us-west-2
```

### 2. Deploy GitLab with Helm

```bash
# Add Helm repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Create namespace
kubectl create namespace gitlab

# Install GitLab
helm install gitlab gitlab/gitlab \
  --version 9.0.0 \
  -f values.yaml \
  --namespace gitlab \
  --timeout 15m
```

### 3. Access GitLab

Get the initial root password:

```bash
# Bash
kubectl get secret -n gitlab gitlab-gitlab-initial-root-password \
  -o jsonpath="{.data.password}" | base64 -d

# PowerShell
kubectl get secret -n gitlab gitlab-gitlab-initial-root-password `
  -o jsonpath="{.data.password}" | ForEach-Object { 
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
  }
```

Login at: `http://<your-alb-dns>`
- Username: `root`
- Password: (from command above)


## Configuration Notes

### PostgreSQL Image

Using official `postgres:16-alpine` instead of Bitnami due to repository changes:

```yaml
postgresql:
  image:
    repository: postgres
    tag: "16-alpine"
  auth:
    database: gitlab
```

### NodePort Configuration

ALB routes to NodePort 30080:

```yaml
nginx-ingress:
  controller:
    service:
      type: NodePort
      nodePorts:
        http: 30080
```