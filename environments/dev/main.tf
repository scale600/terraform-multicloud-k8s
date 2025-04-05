terraform {
  required_version = ">= 1.5.0"
  
  backend "s3" {
    # Backend configuration will be provided via -backend-config flags
    # or during terraform init
  }
}

module "eks_cluster" {
  source = "../../"
  
  environment = "dev"
  
  # These values can be overridden from terraform.tfvars
  cluster_name        = var.cluster_name
  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  cluster_version     = var.cluster_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
} 