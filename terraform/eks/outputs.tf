### CLUSTER ###
output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Configure kubectl: run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

### NETWORKING ###
output "shared_alb_dns_name" {
  value = module.shared_alb.dns_name
}

output "shared_alb_arn" {
  value = module.shared_alb.arn
}

output "gitlab_target_group_arn" {
  value       = aws_lb_target_group.gitlab_nginx.arn
  description = "ARN of GitLab target group"
}