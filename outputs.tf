output "primary" {
  description = "Primary region OKE infrastructure details."
  value = {
    region                     = var.primary_region
    region_short_name          = module.primary_oke.region_short_name
    cluster_id                 = module.primary_oke.cluster_id
    cluster_name               = module.primary_oke.cluster_name
    node_pool_id               = module.primary_oke.node_pool_id
    vcn_id                     = module.primary_oke.vcn_id
    subnet_ids                 = module.primary_oke.subnet_ids
    nsg_ids                    = module.primary_oke.nsg_ids
    object_storage_buckets     = module.primary_oke.object_storage_buckets
    file_storage               = module.primary_oke.file_storage
    kubeconfig_command         = "oci ce cluster create-kubeconfig --cluster-id ${module.primary_oke.cluster_id} --file $HOME/.kube/config --region ${var.primary_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_public_command  = "oci ce cluster create-kubeconfig --cluster-id ${module.primary_oke.cluster_id} --file $HOME/.kube/config --region ${var.primary_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_private_command = "oci ce cluster create-kubeconfig --cluster-id ${module.primary_oke.cluster_id} --file $HOME/.kube/config --region ${var.primary_region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT"
  }
}

output "standby" {
  description = "Standby region OKE infrastructure details."
  value = {
    region                     = var.standby_region
    region_short_name          = module.standby_oke.region_short_name
    cluster_id                 = module.standby_oke.cluster_id
    cluster_name               = module.standby_oke.cluster_name
    node_pool_id               = module.standby_oke.node_pool_id
    vcn_id                     = module.standby_oke.vcn_id
    subnet_ids                 = module.standby_oke.subnet_ids
    nsg_ids                    = module.standby_oke.nsg_ids
    object_storage_buckets     = module.standby_oke.object_storage_buckets
    kubeconfig_command         = "oci ce cluster create-kubeconfig --cluster-id ${module.standby_oke.cluster_id} --file $HOME/.kube/config --region ${var.standby_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_public_command  = "oci ce cluster create-kubeconfig --cluster-id ${module.standby_oke.cluster_id} --file $HOME/.kube/config --region ${var.standby_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_private_command = "oci ce cluster create-kubeconfig --cluster-id ${module.standby_oke.cluster_id} --file $HOME/.kube/config --region ${var.standby_region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT"
  }
}

output "fsdr_iam" {
  description = "Full Stack DR resource-principal IAM resources."
  value = var.enable_fsdr_iam && local.fsdr_iam_tenancy_ocid != null ? {
    home_region          = local.home_region
    tenancy_ocid         = local.fsdr_iam_tenancy_ocid
    target_compartment   = var.compartment_ocid
    dynamic_group_id     = oci_identity_dynamic_group.fsdr_resource_principals[0].id
    dynamic_group_name   = oci_identity_dynamic_group.fsdr_resource_principals[0].name
    policy_id            = oci_identity_policy.fsdr_resource_principal[0].id
    policy_name          = oci_identity_policy.fsdr_resource_principal[0].name
    policy_statement_cnt = length(local.fsdr_policy_permissions)
  } : null
}
