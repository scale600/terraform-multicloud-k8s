#!/bin/bash
set -e

# Check if environment parameter is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <environment>"
  echo "Example: $0 dev"
  exit 1
fi

ENVIRONMENT=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory $ENV_DIR not found"
  exit 1
fi

# Extract cluster name and region from Terraform outputs
echo "Retrieving cluster info from Terraform outputs..."
cd "$ENV_DIR"
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)

# Ensure kubectl is configured for the cluster
echo "Configuring kubectl for cluster $CLUSTER_NAME in region $REGION..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# Create namespaces
echo "Creating namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Metrics Server
echo "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for metrics server to be ready
echo "Waiting for Metrics Server to be ready..."
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=90s

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw security_load_balancer_controller_role_arn) \
  --set region="$REGION" \
  --set vpcId=$(terraform output -raw vpc_id)

# Install Cluster Autoscaler
echo "Installing Cluster Autoscaler..."
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName="$CLUSTER_NAME" \
  --set awsRegion="$REGION" \
  --set rbac.serviceAccount.create=true \
  --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw security_cluster_autoscaler_role_arn) \
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.expander=least-waste

# Install Prometheus and Grafana stack
echo "Installing Prometheus and Grafana stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$PROJECT_ROOT/helm/prometheus/values.yaml"

# Install Falco for security monitoring
echo "Installing Falco security monitoring..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm upgrade --install falco falcosecurity/falco \
  --namespace monitoring \
  --values "$PROJECT_ROOT/helm/falco/values.yaml"

# Install ArgoCD for GitOps
echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values "$PROJECT_ROOT/helm/argocd/values.yaml"

# Run CIS Benchmark compliance checks
echo "Running CIS Benchmark compliance checks..."
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
sleep 5
kubectl wait --for=condition=complete job/kube-bench --timeout=300s
echo "CIS Benchmark results:"
kubectl logs job/kube-bench

echo "All addons installed successfully!"
echo "To access the ArgoCD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "To get the ArgoCD admin password, run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d" 