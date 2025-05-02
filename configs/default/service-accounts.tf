resource "yandex_iam_service_account" "terraform" {
  name        = "terraform"
  folder_id   = local.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id   = local.folder_id
  role        = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
 folder_id = local.folder_id
 role      = "container-registry.images.puller"
 member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_iam_service_account_static_access_key" "terraform-sk" {
  service_account_id = yandex_iam_service_account.terraform.id
  description        = "static access key for object storage"
}
