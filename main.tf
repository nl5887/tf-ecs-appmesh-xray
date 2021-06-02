locals {
  name = "white-hart"

  tags = {
    app = local.name,
    env = "production",
  }

  aws_region_name = "us-east-2"

  egress_filter_allow_all = false
  access_logs_enable      = false
}

resource "aws_ecs_cluster" "current" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "http" {
  name        = "${local.name}-lb-http"
  description = "Allow HTTP ingress traffic to load balancer"
  vpc_id      = aws_vpc.current.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress-all" {
  name        = "${local.name}-lb-egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.current.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "https" {
  name        = "${local.name}-lb-https"
  description = "Allow HTTPS ingress traffic to load balancer"
  vpc_id      = aws_vpc.current.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb" {
  name        = "${local.name}-lb"
  description = "This is the loadbalancer security group, used to allow traffic from the lb"
  vpc_id      = aws_vpc.current.id
}


resource "aws_lb" "current" {
  name               = "lb-${local.name}"
  internal           = false
  load_balancer_type = "application"

  subnets = concat(
    aws_subnet.public[*].id,
//    aws_subnet.private[*].id,
  )

  security_groups = [
    aws_security_group.lb.id,
    aws_security_group.egress-all.id,
    aws_security_group.http.id,
    aws_security_group.https.id,
  ]

  depends_on = [aws_vpc.current]

  dynamic "access_logs" {
    for_each = local.access_logs_enable ? [1] : []
    content {
      bucket  = aws_s3_bucket.lb_logs.bucket
      prefix  = "lb-${local.name}"
      enabled = true
    }
  }

  tags = merge(local.tags, {})
}

resource "aws_appmesh_mesh" "current" {
  name = local.name

  spec {
    dynamic "egress_filter" {
      for_each = local.egress_filter_allow_all ? [1] : []
      content {
        type = "ALLOW_ALL"
      }
    }
  }
}

resource "aws_route53_zone" "private" {
  name = "${local.name}.local"

  vpc {
    vpc_id = aws_vpc.current.id
  }
}

resource "aws_service_discovery_private_dns_namespace" "current" {
  name        = "sd.${aws_route53_zone.private.name}"
  description = "This domain is being used for service discovery."
  vpc         = aws_vpc.current.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.current.arn
  port              = "80"
  protocol          = "HTTP"

  // ssl_policy        = "ELBSecurityPolicy-2016-08"
  // certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.current.arn
  }
  depends_on = [aws_lb_target_group.current]
}

resource "aws_lb_target_group" "current" {
  name        = "lb-tg-${local.name}"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.current.id

  health_check {
    enabled = true
    path    = "/health"
  }
}

module "create-group1-ecs" {
  source = "./modules/ecs"

  service_name    = "${local.name}-group1"
  task_identifier = "xyz"

  lb_target_group = aws_lb_target_group.current

  image = "931700537194.dkr.ecr.us-east-2.amazonaws.com/hello-world:latest"

  app_mesh = aws_appmesh_mesh.current

  container_port = 3000

  cluster     = aws_ecs_cluster.current.id
  private_dns = aws_route53_zone.private

  desired_count = 1

  private_dns_namespace = aws_service_discovery_private_dns_namespace.current

  virtual_node_listener_enable = false

  vpc = aws_vpc.current

  security_groups = [
  ]

  subnets = aws_subnet.private.*.id

  aws_region_name = local.aws_region_name

  backends = [
    module.create-group2-ecs.virtual_node,
  ]

  environment = [{
    name  = "SECRET"
    value = "http://group2-xyz.simpleapp.local:3000"
  }]

  tags = merge(local.tags, {
  })
}

module "create-group2-ecs" {
  source = "./modules/ecs"

  service_name = "${local.name}-group2"

  task_identifier = "xyz"

  image = "931700537194.dkr.ecr.us-east-2.amazonaws.com/hello-world:latest"

  virtual_node_listener_enable = true

  vpc      = aws_vpc.current
  app_mesh = aws_appmesh_mesh.current

  container_port = 3000

  cluster = aws_ecs_cluster.current.id

  private_dns = aws_route53_zone.private

  desired_count = 1

  proxy_configuration_enable = true

  private_dns_namespace = aws_service_discovery_private_dns_namespace.current

  security_groups = [
  ]

  subnets = aws_subnet.private.*.id

  aws_region_name = local.aws_region_name

  environment = []

  tags = merge(local.tags, {
  })
}
