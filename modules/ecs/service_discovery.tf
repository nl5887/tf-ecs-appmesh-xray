resource "aws_service_discovery_service" "current" {
  name            = "${local.name}"
  dns_config {
    namespace_id = var.private_dns_namespace.id
    dns_records {
      ttl = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 2
  }
}

