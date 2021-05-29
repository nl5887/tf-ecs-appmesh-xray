resource "aws_iam_role" "task-execution-role" {
  name               = "${local.name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-task-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
    "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
}

resource "aws_iam_role_policy_attachment" "task-execution-role" {
  role       = aws_iam_role.task-execution-role.name
  policy_arn = data.aws_iam_policy.ecs-task-execution-role.arn
}

data "aws_iam_policy" "ecs-task-execution-role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs-task-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

