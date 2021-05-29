locals {
  name = "${var.service_name}-${var.task_identifier}"

  task_role_arn = aws_iam_role.task-execution-role.arn
  execution_role_arn = aws_iam_role.task-execution-role.arn
  
  security_groups = concat(var.security_groups, [
    aws_security_group.egress-all.id,
    aws_security_group.api-ingress.id,
    aws_security_group.api-envoy.id,
  ])

  tags = merge(var.tags, {
    component = "${local.name}"
  })
}

