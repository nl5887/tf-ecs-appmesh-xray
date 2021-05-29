resource "aws_appmesh_virtual_service" "current" {
  name      = "${local.name}.${var.private_dns.name}"
  mesh_name = var.app_mesh.name

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.current.name
      }
    }
  }
}

resource "aws_appmesh_virtual_router" "current" {
  name      = "${local.name}-router"
  mesh_name = var.app_mesh.name

  spec {
    listener {
      port_mapping {
        port     = var.container_port
        protocol = "http"
      }
    }
  }
}

resource "aws_appmesh_virtual_node" "current" {
  name            = "${local.name}-node"
  mesh_name = var.app_mesh.name

  spec {
    
    dynamic "listener" {
      for_each = var.virtual_node_listener_enable ? [1] : []
      content {
        port_mapping {
          port     = var.container_port
          protocol = "http"
        }
      }
    }

    dynamic "service_discovery" {
      for_each = var.virtual_node_listener_enable ? [1] : []
      content {
        dns {
          hostname = "${aws_service_discovery_service.current.name}.${var.private_dns_namespace.name}"
        }
      }
    }

    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }

    dynamic "backend" {
      for_each = var.backends
      content {
        virtual_service {
          virtual_service_name = backend.value
        }
      }
    }
    
  }
}

resource "aws_appmesh_route" "current" {
  name            = "${local.name}-route"
  mesh_name = var.app_mesh.name
  virtual_router_name = aws_appmesh_virtual_router.current.name

  depends_on = [aws_appmesh_virtual_router.current]

  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = aws_appmesh_virtual_node.current.name
          weight       = 100
        }
      }
    }
  }
}
