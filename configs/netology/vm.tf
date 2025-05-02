locals {
  netology_instance_type = {
    stage = "standard-v1"
    prod = "standard-v2"
  }
}

locals {
  scale_size_worker = {
    stage = 2
    prod = 3
  }
}

locals {
  scale_size_master = {
    stage = 1
    prod = 3
  }
}

locals {
  resources_core_fraction = {
    stage = 100
    prod = 100
  }
}

locals {
  preemptible = {
    stage = true
    prod = false
  }
}


resource "yandex_compute_instance_group" "k8s-masters" {
  name                = "k8s-masters-${terraform.workspace}"
  folder_id = local.folder_id
  service_account_id  = local.service_account_id
  deletion_protection = "false"
  depends_on = [
    local.service_account_id,
    local.folder_iam_member,
    yandex_vpc_network.netology-vpc,
    yandex_vpc_subnet.subnet-a,
    yandex_vpc_subnet.subnet-b
#    yandex_vpc_subnet.subnet-d
  ]
  instance_template {
    name = "master-{instance.index}-${terraform.workspace}"
    platform_id = local.netology_instance_type[terraform.workspace]
    resources {
      memory = 4
      cores  = 4
      core_fraction = local.resources_core_fraction[terraform.workspace]
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd80bm0rh4rkepi5ksdi"
        size     = 50
      }
    }

    network_interface {
      network_id = "${yandex_vpc_network.netology-vpc.id}"
      subnet_ids = [
        "${yandex_vpc_subnet.subnet-a.id}",
        "${yandex_vpc_subnet.subnet-b.id}"
#        "${yandex_vpc_subnet.subnet-c.id}" 
     ]
      nat       = true
    }

    scheduling_policy {
      preemptible = local.preemptible[terraform.workspace]
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = local.scale_size_master[terraform.workspace]
    }
  }

  allocation_policy {
    zones = [
      "ru-central1-a",
      "ru-central1-b",
#      "ru-central1-d"
    ]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
    strategy = "opportunistic"
  }
}

resource "yandex_compute_instance_group" "k8s-workers" {
  name                = "k8s-workers-${terraform.workspace}"
  folder_id = local.folder_id
  service_account_id  = local.service_account_id
  deletion_protection = false
  depends_on = [
    local.service_account_id,
    local.folder_iam_member,
    yandex_vpc_network.netology-vpc,
    yandex_vpc_subnet.subnet-a,
    yandex_vpc_subnet.subnet-b
#    yandex_vpc_subnet.subnet-d
  ]
  instance_template {
    name = "worker-{instance.index}-${terraform.workspace}"
    platform_id = local.netology_instance_type[terraform.workspace]
    resources {
      memory = 4
      cores  = 4
      core_fraction = local.resources_core_fraction[terraform.workspace]
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd80bm0rh4rkepi5ksdi"
        size     = 100
      }
    }

    network_interface {
      network_id = "${yandex_vpc_network.netology-vpc.id}"
      subnet_ids = [
        "${yandex_vpc_subnet.subnet-a.id}",
        "${yandex_vpc_subnet.subnet-b.id}"
#        "${yandex_vpc_subnet.subnet-d.id}"
     ]
      nat       = true
    }

    scheduling_policy {
      preemptible = local.preemptible[terraform.workspace]
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = local.scale_size_worker[terraform.workspace]
    }
  }

  allocation_policy {
    zones = [
      "ru-central1-a",
      "ru-central1-b",
#      "ru-central1-c"
    ]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
    strategy = "opportunistic"
  }
}

data "template_file" "inventory" {
  template = file("k8s-hosts.ini.tpl")

  vars = {
    connection_strings_master = join("\n", formatlist("%s ansible_host=%s ip=%s", yandex_compute_instance_group.k8s-masters.instances.*.name, yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.nat_ip_address, yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.ip_address))
    connection_strings_worker = join("\n", formatlist("%s ansible_host=%s ip=%s", yandex_compute_instance_group.k8s-workers.instances.*.name, yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.nat_ip_address, yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.ip_address))
    list_masters              = join("\n", yandex_compute_instance_group.k8s-masters.instances.*.name)
    list_workers              = join("\n", yandex_compute_instance_group.k8s-workers.instances.*.name)
    connection_master         = join(",", formatlist("%s", yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.nat_ip_address))
  }
}

resource "null_resource" "inventories" {
  provisioner "local-exec" {
    command = "echo '${data.template_file.inventory.rendered}' > kubespray/inventory/ntlg_cluster/inventory.ini"
  }

  provisioner "local-exec" {
    command = "sed -i \"s/#supplementary_addresses_in_ssl_keys=.*/supplementary_addresses_in_ssl_keys='$(yc compute instance list --format json | jq -c '[.[] | select(.name | test(\"^master.\")) .network_interfaces[] | .primary_v4_address.one_to_one_nat.address]')'/\" kubespray/inventory/ntlg_cluster/inventory.ini"
  }

  triggers = {
    template = data.template_file.inventory.rendered
  }
}

output "instance_group_masters_public_ips" {
  description = "Public IP addresses master-nodes"
  value = yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.nat_ip_address
}

output "instance_group_masters_private_ips" {
  description = "Private IP addresses master-nodes"
  value = yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.ip_address
}

output "instance_group_workers_public_ips" {
  description = "Public IP addresses worder-nodes"
  value = yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.nat_ip_address
}

output "instance_group_workers_private_ips" {
  description = "Private IP addresses worker-nodes"
  value = yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.ip_address
}

#output "test1" {
#  description = "Public IP addresses for all master-nodes"
#  value = formatlist("%s", yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.nat_ip_address)
#}

#output "test2" {
#  description = "Public IP addresses for all master-nodes"
#  value = split(",", join(",", formatlist("%s", yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.nat_ip_address)))
#}
