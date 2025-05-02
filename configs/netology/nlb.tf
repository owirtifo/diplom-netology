locals {
  workers_ip_addr = yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.ip_address
  workers_subnet_id = yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.subnet_id

  workers = zipmap(local.workers_ip_addr,local.workers_subnet_id)

}

resource "yandex_lb_network_load_balancer" "k8s-nlb" {
  name = "k8s-nlb"
  deletion_protection = "false"
  listener {
    name        = "app-listener"
    port        = 443
    target_port = 32443
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.ntlg-tgroup.id
    healthcheck {
      name                = "tcp"
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2
      tcp_options {
        port = 32443
      }
    }
  }
}

resource "yandex_lb_target_group" "ntlg-tgroup" {
  name      = "ntlg-tgroup"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = local.workers
    content {
      subnet_id = target.value
      address   = target.key
    }
  }
}

output "nlb_ip_address" {
  description = "IP Address NLB"
  value = yandex_lb_network_load_balancer.k8s-nlb.listener.*.external_address_spec
}
