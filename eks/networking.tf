module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

module "shared_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.cluster_name}-shared-alb"
  load_balancer_type = "application"
  internal           = false
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = false

  # Required so AWS Load Balancer Controller can adopt it
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "ingress.k8s.aws/resource"                  = "LoadBalancer"
    }
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = module.shared_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab_nginx.arn
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Shared ALB SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Target Group for GitLab NGINX Ingress
resource "aws_lb_target_group" "gitlab_nginx" {
  name        = "${var.cluster_name}-gitlab-tg"
  port        = 30080  # NodePort where GitLab NGINX listens
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/healthz"
    port                = "30080"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "gitlab-nginx-tg"
    }
  )
}

resource "aws_autoscaling_attachment" "gitlab_asg" {
  autoscaling_group_name = module.eks.eks_managed_node_groups["minimal"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.gitlab_nginx.arn
}

# Add listener rule for /gitlab path
# resource "aws_lb_listener_rule" "gitlab" {
#   listener_arn = aws_lb_listener.http.arn
#   priority     = 100

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.gitlab_nginx.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/gitlab", "/gitlab/*"]
#     }
#   }
# }

# Allow ALB to reach worker nodes on NodePort
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow ALB to reach GitLab NGINX on NodePort"
}