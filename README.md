# Cloud-Native Infrastructure as Code (IaC)
## Automated Multi-Cloud Kubernetes Cluster

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)

This repository contains production-ready Terraform code for deploying and managing Kubernetes clusters across multiple cloud providers, with a current focus on AWS EKS.

## 🛠️ Tech Stack

- **Infrastructure as Code**: Terraform v1.5.0+ with AWS provider v4.67.0+
- **Container Orchestration**: Kubernetes (EKS v1.25+)
- **Package Management**: Helm v3.12.0+
- **CI/CD Pipeline**: GitHub Actions
- **GitOps**: ArgoCD v2.7.0+ for declarative continuous delivery
- **Monitoring & Observability**: 
  - Prometheus v2.45.0+ for metrics collection
  - Grafana v9.5.0+ for visualization dashboards
- **Security**:
  - Falco v0.35.0+ for runtime security monitoring
  - kube-bench v0.6.0+ for CIS Benchmark compliance checks

## 📌 Key Features

- **One-click EKS Deployment**: Streamlined cluster provisioning with automated node group configuration
- **Security-first Approach**: CIS Benchmark compliance verification and automated remediation
- **Infrastructure Validation**: Automated testing with Terratest for infrastructure components
- **GitOps Workflows**: ArgoCD applications automatically synced from git repositories
- **Multi-environment Support**: Development, staging, and production environments with separate state files
- **Scalability**: Configured horizontal pod autoscaling and cluster autoscaling based on custom metrics

## 📋 Prerequisites

- AWS Account with Administrator access
- Terraform CLI (v1.5.0+)
- kubectl (v1.27.0+)
- AWS CLI (v2.11.0+) configured with access credentials
- Helm (v3.12.0+)
- Git (v2.40.0+)

## 🚀 Getting Started

### AWS Configuration

1. Create an AWS IAM user with programmatic access and the following policies:
   - AmazonEKSClusterPolicy
   - AmazonEKSServicePolicy
   - AmazonVPCFullAccess
   
2. Configure AWS CLI with your credentials:
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, region (e.g., us-west-2), and output format (json)
   ```
   
3. Verify AWS CLI configuration:
   ```bash
   aws sts get-caller-identity
   # Should display your account ID, user ID, and ARN
   ```

### Repository Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/terraform-multicloud-k8s.git
   cd terraform-multicloud-k8s
   ```

2. Initialize Terraform with backend configuration for state storage:
   ```bash
   # Create S3 bucket for state storage (optional but recommended)
   aws s3 mb s3://terraform-k8s-state-$(aws sts get-caller-identity --query Account --output text)
   
   # Initialize Terraform
   terraform init -backend-config="bucket=terraform-k8s-state-$(aws sts get-caller-identity --query Account --output text)" -backend-config="key=eks/terraform.tfstate" -backend-config="region=us-west-2"
   ```

### Configuration Customization

1. Review and customize the variables in `terraform.tfvars`:
   ```bash
   cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
   ```
   
2. Edit `environments/dev/terraform.tfvars` with your configuration:
   ```hcl
   # Example terraform.tfvars content
   cluster_name        = "dev-eks-cluster"
   aws_region          = "us-west-2"
   vpc_cidr            = "10.0.0.0/16"
   availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]
   cluster_version     = "1.27"
   node_instance_types = ["t3.medium"]
   node_desired_size   = 2
   node_max_size       = 5
   node_min_size       = 1
   ```

### Deployment

1. Switch to the environment directory and create an execution plan:
   ```bash
   cd environments/dev
   terraform plan -out=tfplan
   ```

2. Review the execution plan and apply the configuration:
   ```bash
   terraform apply tfplan
   ```
   Estimated deployment time: 15-20 minutes for EKS cluster creation

3. Configure kubectl to interact with your new cluster:
   ```bash
   aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw region)
   
   # Verify connection
   kubectl get nodes
   ```

### Post-Deployment Setup

1. Deploy core addons to the cluster:
   ```bash
   cd ../../scripts
   ./deploy-addons.sh dev
   ```
   
   This script installs:
   - AWS Load Balancer Controller
   - Cluster Autoscaler
   - External DNS
   - Metrics Server
   - Prometheus and Grafana stack
   - Falco security monitoring

2. Deploy ArgoCD for GitOps:
   ```bash
   kubectl create namespace argocd
   helm repo add argo https://argoproj.github.io/argo-helm
   helm install argocd argo/argo-cd -n argocd -f helm/argocd/values.yaml
   
   # Get ArgoCD admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   
   # Port forward to access UI
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access at https://localhost:8080
   ```

3. Run security compliance checks:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
   kubectl logs -l app=kube-bench
   ```

## 📂 Project Structure and Key Files

```
.
├── environments/                    # Environment-specific configurations
│   ├── dev/
│   │   ├── main.tf                  # Dev environment configuration
│   │   ├── terraform.tfvars.example # Example variables for dev
│   │   └── backend.tf               # State backend configuration
│   ├── staging/
│   └── prod/
├── modules/                         # Reusable Terraform modules
│   ├── eks/                         # EKS cluster configuration
│   │   ├── main.tf                  # Main EKS configuration
│   │   ├── variables.tf             # Input variables
│   │   ├── outputs.tf               # Output values
│   │   └── iam.tf                   # IAM roles and policies
│   ├── networking/                  # VPC and subnet configurations
│   │   ├── main.tf                  # VPC, subnets, routing
│   │   ├── variables.tf             # Input variables
│   │   └── outputs.tf               # Output values
│   └── security/                    # Security groups and policies
├── helm/                            # Helm charts for Kubernetes applications
│   ├── argocd/
│   │   └── values.yaml              # ArgoCD configuration
│   ├── prometheus/
│   │   └── values.yaml              # Prometheus configuration
│   └── grafana/
│       └── values.yaml              # Grafana configuration
├── scripts/                         # Utility scripts
│   ├── deploy-addons.sh             # Installs cluster addons
│   ├── cleanup.sh                   # Resource cleanup script
│   └── monitoring-setup.sh          # Configures monitoring stack
├── .github/workflows/               # GitHub Actions CI/CD pipelines
│   ├── terraform-validate.yml       # Validates Terraform code
│   ├── terraform-plan.yml           # Creates execution plan
│   └── terraform-apply.yml          # Applies configuration
├── main.tf                          # Root module configuration
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
└── README.md                        # Project documentation
```

## 🛡️ Security Features

- **CIS Benchmark Compliance**: Automated checks using kube-bench
  ```bash
  # Run compliance checks
  kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
  kubectl logs -l app=kube-bench
  ```

- **Network Policies**: Default deny-all with explicit allowances
  ```yaml
  # Example network policy in helm/network-policies/values.yaml
  policies:
    - name: default-deny-all
      spec:
        podSelector: {}
        policyTypes:
        - Ingress
        - Egress
  ```

- **RBAC**: Fine-grained role-based access control
  ```yaml
  # Example RBAC configuration in modules/eks/iam.tf
  resource "aws_iam_role" "eks_developer" {
    name = "eks-developer-role"
    # Role definition with least privilege access
  }
  ```

- **Secrets Management**: Using AWS Secrets Manager and Kubernetes secrets
  ```bash
  # Example for creating and using secrets
  aws secretsmanager create-secret --name dev/db-credentials \
    --description "Database credentials for development" \
    --secret-string '{"username":"admin","password":"example-password"}'
  ```

- **Runtime Security Monitoring**: Falco configured with custom rules
  ```yaml
  # Example Falco custom rules in helm/falco/values.yaml
  customRules:
    rules-aws.yaml: |-
      - rule: AWS Credentials Accessed
        desc: Detect attempts to access AWS credentials
        condition: >
          spawned_process and
          (proc.name = "cat" or proc.name = "ls") and
          (proc.args contains "credentials" or
           proc.args contains ".aws/config")
        output: AWS credentials accessed by process (user=%user.name command=%proc.cmdline)
        priority: WARNING
  ```

## 📊 Monitoring and Observability Configuration

The project includes a comprehensive monitoring stack with these specific configurations:

- **Prometheus**: Configured to scrape metrics from all cluster components
  ```yaml
  # Example Prometheus configuration in helm/prometheus/values.yaml
  server:
    retention: 15d
    scrapeInterval: 30s
    scrapeTimeout: 10s
    evaluationInterval: 30s
  alertmanager:
    enabled: true
    # Alert configurations
  ```

- **Grafana**: Pre-configured dashboards for cluster insights
  ```yaml
  # Example Grafana configuration in helm/grafana/values.yaml
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 6417
        revision: 1
        datasource: Prometheus
  ```

- **Alerting**: Email and Slack notification channels
  ```yaml
  # Example alerting configuration
  alerting:
    alertmanagers:
    - static_configs:
      - targets:
        - alertmanager.monitoring.svc:9093
  ```

- **Logs**: FluentD for log aggregation to CloudWatch
  ```bash
  # Install FluentD using Helm
  helm repo add fluent https://fluent.github.io/helm-charts
  helm install fluent-bit fluent/fluent-bit \
    --namespace monitoring \
    --set backend.type=cloudwatch \
    --set cloudWatch.region=us-west-2 \
    --set cloudWatch.logGroupName=/aws/eks/$(terraform output -raw cluster_name)/logs
  ```

## 🔄 Continuous Integration and Deployment

- **Terraform Validation Pipeline**: 
  ```yaml
  # Example GitHub Actions workflow in .github/workflows/terraform-validate.yml
  name: Terraform Validate
  on:
    push:
      branches: [ main, develop ]
    pull_request:
      branches: [ main, develop ]
  
  jobs:
    validate:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v3
        - uses: hashicorp/setup-terraform@v2
          with:
            terraform_version: 1.5.0
        - name: Terraform Format Check
          run: terraform fmt -check -recursive
        - name: Terraform Init
          run: terraform init -backend=false
        - name: Terraform Validate
          run: terraform validate
  ```

- **GitOps Workflow with ArgoCD**: Configure applications to sync from Git
  ```yaml
  # Example ArgoCD application in helm/argocd/applications/prometheus.yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: prometheus
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: https://github.com/your-username/kubernetes-manifests.git
      targetRevision: HEAD
      path: prometheus
    destination:
      server: https://kubernetes.default.svc
      namespace: monitoring
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
  ```

## 🚧 Troubleshooting

### Common Issues and Solutions

1. **EKS Cluster Creation Fails**:
   ```bash
   # Check CloudFormation stack status
   aws cloudformation list-stacks --query "StackSummaries[?StackName=='eksctl-${CLUSTER_NAME}-cluster']"
   
   # View detailed error
   aws cloudformation describe-stack-events --stack-name "eksctl-${CLUSTER_NAME}-cluster" --max-items 5
   ```

2. **Nodes Not Joining Cluster**:
   ```bash
   # Check node status
   kubectl get nodes
   
   # View ASG status
   aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(Tags[?Key=='eks:cluster-name'].Value, '${CLUSTER_NAME}')]"
   
   # Check node bootstrap logs
   aws ec2 get-console-output --instance-id <instance-id>
   ```

3. **ArgoCD Sync Issues**:
   ```bash
   # Check application status
   kubectl get applications -n argocd
   
   # View detailed sync info
   argocd app get <app-name> --hard-refresh
   ```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Commit changes with conventional commit messages:
   ```bash
   git commit -m "feat: add support for GCP clusters"
   ```
4. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
5. Submit a pull request with a detailed description of changes

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
