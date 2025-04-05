terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
  }
  
  backend "s3" {
    # Backend configuration will be provided via -backend-config flags
    # or during terraform init
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "terraform-multicloud-k8s"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Include modules based on the active environment

module "networking" {
  source = "./modules/networking"
  
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "eks" {
  source = "./modules/eks"
  
  depends_on = [module.networking]
  
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

module "security" {
  source = "./modules/security"
  
  environment  = var.environment
  cluster_name = var.cluster_name
  vpc_id       = module.networking.vpc_id
  eks_oidc_url = module.eks.oidc_provider_url
  eks_oidc_arn = module.eks.oidc_provider_arn
} 