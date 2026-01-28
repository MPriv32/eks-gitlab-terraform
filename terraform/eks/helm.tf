resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
  }

  depends_on = [module.eks]
}

resource "null_resource" "helm_repo_eks" {
  provisioner "local-exec" {
    command = "helm repo add eks https://aws.github.io/eks-charts && helm repo update"
  }
}

resource "helm_release" "aws_lb_controller" {
  name      = "aws-load-balancer-controller"
  chart     = "eks/aws-load-balancer-controller"
  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  # IMPORTANT: IRSA hookup
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller.arn
  }

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.aws_lb_controller_attach,
    aws_iam_role_policy_attachment.ebs_csi_driver_attach,
    null_resource.update_kubeconfig
  ]
}
