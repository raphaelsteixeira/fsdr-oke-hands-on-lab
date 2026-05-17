output "primary" {
  description = "Primary region OKE infrastructure details."
  value = {
    region                          = var.primary_region
    region_short_name               = module.primary_oke.region_short_name
    cluster_id                      = module.primary_oke.cluster_id
    cluster_name                    = module.primary_oke.cluster_name
    node_pool_id                    = module.primary_oke.node_pool_id
    vcn_id                          = module.primary_oke.vcn_id
    drg                             = module.primary_oke.drg
    subnet_ids                      = module.primary_oke.subnet_ids
    nsg_ids                         = module.primary_oke.nsg_ids
    object_storage_buckets          = module.primary_oke.object_storage_buckets
    object_storage_private_endpoint = module.primary_oke.object_storage_private_endpoint
    file_storage                    = module.primary_oke.file_storage
    kubeconfig_command              = "oci ce cluster create-kubeconfig --cluster-id ${module.primary_oke.cluster_id} --file $HOME/.kube/config --region ${var.primary_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_public_command       = "oci ce cluster create-kubeconfig --cluster-id ${module.primary_oke.cluster_id} --file $HOME/.kube/config --region ${var.primary_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_private_command      = "oci ce cluster create-kubeconfig --cluster-id ${module.primary_oke.cluster_id} --file $HOME/.kube/config --region ${var.primary_region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT"
  }
}

output "standby" {
  description = "Standby region OKE infrastructure details."
  value = {
    region                          = var.standby_region
    region_short_name               = module.standby_oke.region_short_name
    cluster_id                      = module.standby_oke.cluster_id
    cluster_name                    = module.standby_oke.cluster_name
    node_pool_id                    = module.standby_oke.node_pool_id
    vcn_id                          = module.standby_oke.vcn_id
    drg                             = module.standby_oke.drg
    subnet_ids                      = module.standby_oke.subnet_ids
    nsg_ids                         = module.standby_oke.nsg_ids
    object_storage_buckets          = module.standby_oke.object_storage_buckets
    object_storage_private_endpoint = module.standby_oke.object_storage_private_endpoint
    kubeconfig_command              = "oci ce cluster create-kubeconfig --cluster-id ${module.standby_oke.cluster_id} --file $HOME/.kube/config --region ${var.standby_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_public_command       = "oci ce cluster create-kubeconfig --cluster-id ${module.standby_oke.cluster_id} --file $HOME/.kube/config --region ${var.standby_region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
    kubeconfig_private_command      = "oci ce cluster create-kubeconfig --cluster-id ${module.standby_oke.cluster_id} --file $HOME/.kube/config --region ${var.standby_region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT"
  }
}

output "drg_peering" {
  description = "Cross-region DRG remote peering connection details."
  value = {
    primary = {
      rpc_id         = oci_core_remote_peering_connection.primary.id
      rpc_name       = oci_core_remote_peering_connection.primary.display_name
      peering_status = oci_core_remote_peering_connection.primary.peering_status
      peer_region    = var.standby_region
    }
    standby = {
      rpc_id         = oci_core_remote_peering_connection.standby.id
      rpc_name       = oci_core_remote_peering_connection.standby.display_name
      peering_status = oci_core_remote_peering_connection.standby.peering_status
      peer_region    = var.primary_region
    }
  }
}

output "object_storage_cross_region_access" {
  description = "Destination private endpoints and routed CIDRs for cross-region Object Storage writes."
  value = {
    primary_to_standby = {
      source_region              = var.primary_region
      source_worker_subnet_cidr  = var.primary_worker_subnet_cidr
      source_pod_subnet_cidr     = var.primary_pod_subnet_cidr
      destination_region         = var.standby_region
      destination_vcn_cidr       = var.standby_vcn_cidr
      destination_worker_cidr    = var.standby_worker_subnet_cidr
      destination_pod_cidr       = var.standby_pod_subnet_cidr
      destination_endpoint_fqdn  = module.standby_oke.object_storage_private_endpoint.private_endpoint_fqdn
      destination_endpoint_ip    = module.standby_oke.object_storage_private_endpoint.private_endpoint_ip
      destination_allowed_cidrs  = module.standby_oke.object_storage_private_endpoint.allowed_source_cidrs
      destination_bucket_targets = module.standby_oke.object_storage_private_endpoint.access_target_bucket_names
    }
    standby_to_primary = {
      source_region              = var.standby_region
      source_worker_subnet_cidr  = var.standby_worker_subnet_cidr
      source_pod_subnet_cidr     = var.standby_pod_subnet_cidr
      destination_region         = var.primary_region
      destination_vcn_cidr       = var.primary_vcn_cidr
      destination_worker_cidr    = var.primary_worker_subnet_cidr
      destination_pod_cidr       = var.primary_pod_subnet_cidr
      destination_endpoint_fqdn  = module.primary_oke.object_storage_private_endpoint.private_endpoint_fqdn
      destination_endpoint_ip    = module.primary_oke.object_storage_private_endpoint.private_endpoint_ip
      destination_allowed_cidrs  = module.primary_oke.object_storage_private_endpoint.allowed_source_cidrs
      destination_bucket_targets = module.primary_oke.object_storage_private_endpoint.access_target_bucket_names
    }
  }
}

output "fsdr_iam" {
  description = "Full Stack DR resource-principal IAM resources."
  value = var.enable_fsdr_iam && local.fsdr_iam_tenancy_ocid != null ? {
    home_region          = coalesce(var.home_region, var.primary_region)
    tenancy_ocid         = local.fsdr_iam_tenancy_ocid
    target_compartment   = var.compartment_ocid
    dynamic_group_id     = oci_identity_dynamic_group.fsdr_resource_principals[0].id
    dynamic_group_name   = oci_identity_dynamic_group.fsdr_resource_principals[0].name
    policy_id            = oci_identity_policy.fsdr_resource_principal[0].id
    policy_name          = oci_identity_policy.fsdr_resource_principal[0].name
    policy_statement_cnt = length(local.fsdr_policy_permissions)
  } : null
}
