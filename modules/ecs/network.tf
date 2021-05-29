
resource "aws_security_group" "api-ingress" {
  name        = "${local.name}-ingress-api"
  description = "Allow ingress to API"
  vpc_id      = var.vpc.id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]

    // todo(remco): we only want to allow traffic from lb-${local.name} security group, allowing only the lb to reach the api
    // source_security_group_id - (Optional) Security group id to allow access to/from, depending on the type. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or self.
  }

  tags = merge(local.tags, {
  })
}

resource "aws_security_group" "egress-all" {
  name        = "${local.name}-egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = var.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
  })
}

resource "aws_security_group" "api-envoy" {
  name        = "${local.name}-ingress-envoy"
  description = "Allow ingress to Envoy"
  vpc_id      = var.vpc.id

  ingress {
    from_port   = 15000
    to_port     = 15000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
  })
}
