resource "aws_ecs_service" "current" {
  name            = "${local.name}"
  cluster         = var.cluster
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  task_definition = aws_ecs_task_definition.current.arn

  depends_on      = [local.task_role_arn]

  // do we want to register with a loadbalancer?
  dynamic "load_balancer" {
    for_each = var.lb_target_group != null ? [1] : []
    content {
      target_group_arn = var.lb_target_group.arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [task_definition]
  }  

  network_configuration {
    assign_public_ip = false
    security_groups = local.security_groups
    subnets = var.subnets
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.current.arn}"
    container_name = "${local.name}"
  }

  tags = merge(local.tags, {
  })
}

resource "aws_ecs_task_definition" "current" {
  family                = "${local.name}"
  requires_compatibilities= ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  task_role_arn = local.task_role_arn 
  execution_role_arn = local.execution_role_arn 

  proxy_configuration {
    type           = "APPMESH"
    container_name = "envoy"
    properties = {
      AppPorts         = var.virtual_node_listener_enable ? var.container_port : 1337
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }

  container_definitions = jsonencode(concat([
    {
      name = var.service_name,
      image = var.image
      essential = true,
      environment = var.environment
      portMappings = [
        {
          containerPort = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region = var.aws_region_name
          awslogs-group = aws_cloudwatch_log_group.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
      dependsOn = var.proxy_configuration_enable ? [{
        containerName = "envoy"
        condition = "HEALTHY"
      }]: []
    }],
    [{
      name = "envoy"
      image = "public.ecr.aws/appmesh/aws-appmesh-envoy:v1.17.3.0-prod"
      essential = true
      portMappings = [
        {
          containerPort: 9901
          protocol: "tcp"
        },
        {
          containerPort: 15000
          protocol: "tcp"
        },
        {
          containerPort: 15001
          protocol: "tcp"
        }
      ]
      environment = [
        {
          name = "APPMESH_VIRTUAL_NODE_NAME"
          value = "mesh/${aws_appmesh_virtual_node.current.mesh_name}/virtualNode/${aws_appmesh_virtual_node.current.name}"
        },
        {
          name = "ENVOY_LOG_LEVEL"
          value = "info"
        },
        {
          name ="XRAY_DAEMON_PORT"
          value ="2000"
        },
        {
          name ="ENABLE_ENVOY_XRAY_TRACING"
          value ="1"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region = var.aws_region_name
          awslogs-group = aws_cloudwatch_log_group.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
        ]
        interval = 120
        retries = 3
        startPeriod = 10
        timeout = 2
      },
      memory = 500
      user = "1337"
    }],[
      {
        name: "xray-daemon"
        image: "public.ecr.aws/xray/aws-xray-daemon:latest"
        user: "1337"
        essential: true
        cpu: 32
        memoryReservation: 256
        portMappings: [
          {
            containerPort: 2000
            protocol: "udp"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-region = var.aws_region_name
            awslogs-group = aws_cloudwatch_log_group.current.name
            awslogs-stream-prefix = "ecs"
          }
        }
      }]
    ))
}
