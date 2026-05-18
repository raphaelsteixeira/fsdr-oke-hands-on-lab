provider "oci" {
  alias  = "primary"
  region = var.primary_region

  auth                 = var.auth
  config_file_profile  = var.config_file_profile
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
}

provider "oci" {
  alias  = "standby"
  region = var.standby_region

  auth                 = var.auth
  config_file_profile  = var.config_file_profile
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
}
