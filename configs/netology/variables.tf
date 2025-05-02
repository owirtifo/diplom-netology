variable "YC_DEFAULT_REGION" {
  description = "YC Region"
  type        = string
}

variable "BK_ACCESS_KEY" {
  description = "Backend access key"
  type        = string
  sensitive   = true
}

variable "BK_SECRET_KEY" {
  description = "Backend secret key"
  type        = string
  sensitive   = true
}
