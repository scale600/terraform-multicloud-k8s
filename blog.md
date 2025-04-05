# Building Production-Ready Kubernetes Infrastructure with Terraform: Multi-Cloud K8s Project

![Terraform and Kubernetes logos](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/tw4qh209fzg7i1zp7s46.png)

## Introduction

In today's cloud-native landscape, organizations are increasingly adopting Kubernetes to orchestrate containerized applications. However, setting up and managing Kubernetes clusters that are production-ready, secure, and scalable remains a challenge. This is where Infrastructure as Code (IaC) tools like Terraform become essential.

In this blog post, I'll introduce the **terraform-multicloud-k8s** project: an open-source solution for automating the deployment of production-grade Kubernetes clusters across multiple cloud providers, with a current focus on AWS EKS (Elastic Kubernetes Service).

## Project Overview

The **terraform-multicloud-k8s** project provides a comprehensive framework for deploying and managing Kubernetes infrastructure with a focus on:

- **Security first**: CIS Benchmark compliance built-in
- **GitOps workflows**: Continuous delivery with ArgoCD
- **Observability**: Integrated monitoring with Prometheus and Grafana
- **Automation**: One-click deployment with CI/CD pipelines

The project is designed to help DevOps teams quickly set up production-ready Kubernetes clusters while adhering to cloud best practices and security standards.

## Architecture

The project follows a modular architecture with separation of concerns:

![Architecture Diagram](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/9mhjlkqv7x2t3p4oeyf6.png)

### Core Components

1. **Terraform Modules**
   - **Networking**: Creates VPC, subnets, and all necessary networking infrastructure
   - **EKS**: Provisions the Kubernetes cluster, node groups, and IAM roles
   - **Security**: Implements security groups, IAM policies for cluster add-ons

2. **Kubernetes Add-ons**
   - **ArgoCD**: GitOps continuous delivery tool
   - **Prometheus & Grafana**: Monitoring and observability stack
   - **Falco**: Runtime security monitoring
   - **kube-bench**: CIS Benchmark compliance checking

3. **CI/CD Pipeline**
   - GitHub Actions workflows for validation, planning, and application
   - Environment-specific configurations for dev, staging, and production

## Key Features

### One-Click EKS Deployment

The project enables you to deploy a fully configured EKS cluster with a single command. The cluster comes with:

- Properly configured node groups
- Auto-scaling enabled
- Private networking
- Optimized instance types

### Security-First Approach

Security is a core consideration built into every aspect of the infrastructure:

- **CIS Benchmark Compliance**: Automated checks using kube-bench
- **Network Policies**: Default deny-all with explicit allowances
- **RBAC**: Fine-grained access control
- **Falco Security Monitoring**: Runtime detection of suspicious activities
- **IAM Roles**: Least privilege principle applied throughout

### GitOps Workflows

The project implements GitOps best practices using ArgoCD:

- Declarative configuration stored in Git
- Automatic synchronization between Git and cluster state
- Drift detection and remediation
- Application deployment tracking

### Comprehensive Monitoring

A complete monitoring stack is included:

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Pre-configured dashboards for cluster insights
- **Alert Notifications**: Integrated with Slack

## Getting Started

### Prerequisites

To use this project, you'll need:

- AWS Account with Administrator access
- Terraform CLI (v1.5.0+)
- kubectl (v1.27.0+)
- AWS CLI (v2.11.0+)
- Helm (v3.12.0+)
- Git (v2.40.0+)

### Quick Start Guide

#### 1. Clone the Repository

```bash
git clone https://github.com/scale600/terraform-multicloud-k8s.git
cd terraform-multicloud-k8s
```

#### 2. Configure AWS Credentials

```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region (e.g., us-west-2), and output format (json)
```

#### 3. Initialize Terraform

```bash
# Create S3 bucket for state storage (optional but recommended)
aws s3 mb s3://terraform-k8s-state-$(aws sts get-caller-identity --query Account --output text)

# Initialize Terraform
cd environments/dev
terraform init \
  -backend-config="bucket=terraform-k8s-state-$(aws sts get-caller-identity --query Account --output text)" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-west-2"
```

#### 4. Customize Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your desired configuration
```

#### 5. Deploy the Infrastructure

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

#### 6. Access Your Cluster

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw region)
kubectl get nodes
```

#### 7. Deploy Core Add-ons

```bash
cd ../../scripts
./deploy-addons.sh dev
```

## Detailed Walkthrough

### Networking Infrastructure

The networking module creates a complete VPC setup including:

- Public and private subnets across multiple availability zones
- NAT gateways for outbound traffic
- Internet gateway for inbound traffic
- Route tables with appropriate routes

```hcl
module "networking" {
  source = "./modules/networking"
  
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}
```

The VPC is configured with public and private subnets, with Kubernetes services deployed in private subnets for enhanced security, while public-facing services like load balancers are placed in public subnets.

### EKS Cluster Configuration

The EKS module handles the creation and configuration of the Kubernetes control plane and node groups:

```hcl
module "eks" {
  source = "./modules/eks"
  
  environment         = var.environment
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
}
```

Node groups are configured with auto-scaling capabilities, allowing your cluster to adapt to changing workload demands.

### Security Configuration

The security module creates IAM roles for key cluster components:

```hcl
module "security" {
  source = "./modules/security"
  
  environment  = var.environment
  cluster_name = var.cluster_name
  vpc_id       = module.networking.vpc_id
  eks_oidc_url = module.eks.oidc_provider_url
  eks_oidc_arn = module.eks.oidc_provider_arn
}
```

This includes roles for:
- AWS Load Balancer Controller
- Cluster Autoscaler
- External DNS
- Other essential add-ons

### Monitoring Setup

The project includes a comprehensive monitoring stack with Prometheus and Grafana:

```yaml
# Prometheus configuration
prometheus:
  prometheusSpec:
    retention: 15d
    resources:
      limits:
        cpu: 1000m
        memory: 2Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
```

Grafana comes pre-configured with essential dashboards:

```yaml
dashboards:
  default:
    kubernetes-cluster:
      gnetId: 6417
      revision: 1
      datasource: Prometheus
    node-exporter:
      gnetId: 1860
      revision: 23
      datasource: Prometheus
```

### Continuous Integration and Deployment

The project includes GitHub Actions workflows for CI/CD:

- **terraform-validate.yml**: Validates Terraform configurations
- **terraform-plan.yml**: Generates and comments execution plans on PRs
- **terraform-apply.yml**: Applies changes to the infrastructure

This enables a GitOps workflow where infrastructure changes go through code review before being applied.

## Extending the Project

### Adding New Environments

The project supports multiple environments (dev, staging, prod). To add a new environment:

1. Copy the dev directory structure:
   ```bash
   cp -r environments/dev environments/staging
   ```

2. Update the environment-specific variables in `environments/staging/terraform.tfvars`

3. Initialize and apply the new environment:
   ```bash
   cd environments/staging
   terraform init -backend-config="key=staging/terraform.tfstate" [other configs]
   terraform apply
   ```

### Adding Custom Kubernetes Applications

You can leverage ArgoCD to deploy your applications after the cluster is running:

1. Create your application manifests in a Git repository
2. Create an ArgoCD Application manifest:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/your-username/your-app-repo.git
       targetRevision: HEAD
       path: kubernetes/manifests
     destination:
       server: https://kubernetes.default.svc
       namespace: my-app
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

3. Apply the manifest to your cluster:
   ```bash
   kubectl apply -f my-app-argo.yaml
   ```

ArgoCD will automatically deploy and keep your application in sync with the Git repository.

## Future Roadmap

The terraform-multicloud-k8s project is under active development, with plans to:

1. Add support for **GCP GKE** and **Azure AKS**
2. Implement **cost optimization** features and reporting
3. Add **multi-cluster federation** capabilities
4. Include additional security tools and compliance frameworks

## Conclusion

The terraform-multicloud-k8s project offers a powerful starting point for organizations looking to standardize their Kubernetes deployments with best practices built in. By providing a production-ready foundation that emphasizes security, monitoring, and GitOps workflows, it enables teams to focus on delivering value through their applications rather than struggling with infrastructure setup.

Whether you're just starting with Kubernetes or looking to standardize existing deployments, this project provides a solid foundation that can be customized to meet your specific needs.

## Get Involved

The project is open-source and welcomes contributions! Check out the repository at [github.com/scale600/terraform-multicloud-k8s](https://github.com/scale600/terraform-multicloud-k8s) to get started.

If you have questions or suggestions, please open an issue on GitHub or contribute directly via pull requests.

---

*This blog post is part of a series on cloud-native infrastructure automation. Stay tuned for upcoming posts on multi-cloud strategies, GitOps practices, and Kubernetes security.* 