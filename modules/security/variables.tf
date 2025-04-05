variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "eks_oidc_url" {
  description = "URL of the OIDC Provider for IAM roles"
  type        = string
}

variable "eks_oidc_arn" {
  description = "ARN of the OIDC Provider for IAM roles"
  type        = string
} 