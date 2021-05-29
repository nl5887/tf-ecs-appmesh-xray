// currently we cannot combine both service discovery as route53
// https://github.com/hashicorp/terraform-provider-aws/pull/17498

// we are using a work around here, to create dns records,
// this is due to envoy not intercepting dns requests yet.
// so we are creating dummy records, to have the virtual services
// resolve
resource "aws_route53_record" "node" {
  name = "${local.name}-node"
  zone_id = var.private_dns.zone_id
  type    = "A"
  ttl     = "300"
  records = ["10.10.10.10"]
}

resource "aws_route53_record" "service" {
  name = "${local.name}"
  zone_id = var.private_dns.zone_id
  type    = "A"
  ttl     = "300"
  records = ["10.10.10.10"]
}

resource "aws_route53_record" "router" {
  name = "${aws_appmesh_virtual_router.current.name}"
  zone_id = var.private_dns.zone_id
  type    = "A"
  ttl     = "300"
  records = ["10.10.10.10"]
}

