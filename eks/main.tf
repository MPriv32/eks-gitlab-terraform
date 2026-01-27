# EKS Module - minimal configuration with 1 node
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Managed Node Group
  eks_managed_node_groups = {
    minimal = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3a.large"]  # Minimum to run Gitlab
      
      disk_size = 40  # Minimum to run Gitlab

      labels = {
        Environment = "test"
        ManagedBy   = "terraform"
      }

      tags = var.tags
    }
  }

  # Enable IRSA
  enable_irsa = true

  tags = var.tags
}
