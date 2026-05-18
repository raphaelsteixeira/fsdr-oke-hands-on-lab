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
