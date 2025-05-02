terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
      dynamodb = "https://docapi.serverless.yandexcloud.net/ru-central1/<CLOUD_ID>/<DB_ID>"
    }
    bucket     = "netology-bucket"
    region     = "ru-central1"
    key        = "default/terraform.tfstate"
    dynamodb_table = "terraform-lock-table"
    
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
  }
}

provider "yandex" {
  zone = "ru-central1-a"
}

locals {
  folder_id = yandex_resourcemanager_folder.netology.id
}

resource "yandex_resourcemanager_folder" "netology" {
  cloud_id    = "<CLOUD_ID>"
  name        = "netology"
}
