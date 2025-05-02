locals {
  subnet_a_v4_cidr_blocks = {
    stage = ["192.168.4.0/24"]
    prod = ["192.168.1.0/24"]
  }
}

locals {
  subnet_b_v4_cidr_blocks = {
    stage = ["192.168.5.0/24"]
    prod = ["192.168.2.0/24"]
  }
}

locals {
  subnet_d_v4_cidr_blocks = {
    stage = ["192.168.6.0/24"]
    prod = ["192.168.3.0/24"]
  }
}

resource "yandex_vpc_network" "netology-vpc" {
  folder_id   = local.folder_id  
  name = "netology-vpc-${terraform.workspace}"
}

resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a-${terraform.workspace}"
  folder_id   = local.folder_id
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.netology-vpc.id
  v4_cidr_blocks = local.subnet_a_v4_cidr_blocks[terraform.workspace]
}

resource "yandex_vpc_subnet" "subnet-b" {
  name           = "subnet-b-${terraform.workspace}"
  folder_id   = local.folder_id
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.netology-vpc.id
  v4_cidr_blocks = local.subnet_b_v4_cidr_blocks[terraform.workspace]
}

resource "yandex_vpc_subnet" "subnet-d" {
  name           = "subnet-d-${terraform.workspace}"
  folder_id   = local.folder_id
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.netology-vpc.id
  v4_cidr_blocks = local.subnet_d_v4_cidr_blocks[terraform.workspace]
}
