variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "tc2-cluster"
}

variable "ecr_repo_name" {
  description = "ECR respository name"
  type        = string
  default     = "tc2-app"
}