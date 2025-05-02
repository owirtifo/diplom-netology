provider "aws" {
  region = "ru-central1"
  endpoints {
    dynamodb = "https://docapi.serverless.yandexcloud.net/ru-central1/<CLOUD_ID>/${local.db_id}"
  }
  access_key = var.BK_ACCESS_KEY
  secret_key = var.BK_SECRET_KEY
  skip_credentials_validation = true
  skip_metadata_api_check = true
  skip_region_validation = true
  skip_requesting_account_id = true
}

locals {
  db_id = yandex_ydb_database_serverless.terraform-state-lock-db.id
}

resource "yandex_storage_bucket" "netology-bucket" {
  bucket     = "netology-bucket"
  folder_id   = local.folder_id
  access_key = yandex_iam_service_account_static_access_key.terraform-sk.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform-sk.secret_key
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.s3-key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "yandex_kms_symmetric_key" "s3-key" {
  name              = "s3-key"
  folder_id         = local.folder_id
  description       = "encrypt s3 bucket"
  default_algorithm = "AES_128"
  rotation_period   = "8760h"
}

resource "yandex_ydb_database_serverless" "terraform-state-lock-db" {
  name                = "terraform-state-lock-db"
  folder_id           = local.folder_id
  serverless_database {
    storage_size_limit = 1
  }
}

resource "aws_dynamodb_table" "terraform-lock-table" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key  = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
