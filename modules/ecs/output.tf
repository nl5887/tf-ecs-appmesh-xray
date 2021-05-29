output "virtual_node" {
  value = "${aws_appmesh_virtual_service.current.name}" 
}
