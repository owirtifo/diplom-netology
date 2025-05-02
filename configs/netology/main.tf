terraform {
  required_providers {
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
    key        = "terraform.tfstate"
    dynamodb_table = "terraform-lock-table"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
  }
}

provider "yandex" {
  zone = "ru-central1-a"
}

data "terraform_remote_state" "default" {
  backend = "s3"
  config = {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket                  = "netology-bucket"
    region                  = var.YC_DEFAULT_REGION
    key                     = "default/terraform.tfstate"
    access_key = var.BK_ACCESS_KEY
    secret_key = var.BK_SECRET_KEY

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id = true
  }
}

locals {
  folder_id = data.terraform_remote_state.default.outputs.folder_id
  service_account_id = data.terraform_remote_state.default.outputs.service_account_id
  folder_iam_member = data.terraform_remote_state.default.outputs.folder_iam_member
}


