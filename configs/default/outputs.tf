output "folder_id" {
  value = yandex_resourcemanager_folder.netology.id
}

output "service_account_id" {
  value = yandex_iam_service_account.terraform.id
}

output "folder_iam_member" {
  value = yandex_resourcemanager_folder_iam_member.editor
}

