resource "aws_cloudwatch_log_group" "current" {
  name = "/ecs/${var.private_dns.name}/${var.service_name}"

  tags = merge(local.tags, {
  })
}

