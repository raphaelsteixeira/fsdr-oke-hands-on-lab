locals {
  known_region_short_names = {
    eu-frankfurt-1 = "fra"
    eu-madrid-1    = "mad"
  }

  home_region_input                        = try(trimspace(var.home_region), "")
  primary_region_short_name_override_input = try(trimspace(var.primary_region_short_name), "")
  standby_region_short_name_override_input = try(trimspace(var.standby_region_short_name), "")
  node_image_id_input                      = try(trimspace(var.node_image_id), "")
  ssh_public_key_input                     = try(trimspace(var.ssh_public_key), "")

  home_region                        = local.home_region_input != "" ? local.home_region_input : var.primary_region
  primary_region_short_name_override = local.primary_region_short_name_override_input != "" ? local.primary_region_short_name_override_input : null
  standby_region_short_name_override = local.standby_region_short_name_override_input != "" ? local.standby_region_short_name_override_input : null
  node_image_id                      = local.node_image_id_input != "" ? local.node_image_id_input : null
  ssh_public_key                     = local.ssh_public_key_input != "" ? local.ssh_public_key_input : null
  primary_region_short_name = coalesce(
    local.primary_region_short_name_override,
    lookup(local.known_region_short_names, var.primary_region, try(regex("^[a-z]+-(.+)-[0-9]+$", var.primary_region)[0], var.primary_region))
  )
  standby_region_short_name = coalesce(
    local.standby_region_short_name_override,
    lookup(local.known_region_short_names, var.standby_region, try(regex("^[a-z]+-(.+)-[0-9]+$", var.standby_region)[0], var.standby_region))
  )

  node_shape_config = var.node_shape_config != null ? var.node_shape_config : (
    can(regex("Flex$", var.node_shape)) ? {
      ocpus         = var.node_ocpus
      memory_in_gbs = var.node_memory_in_gbs
    } : null
  )
}

module "primary_oke" {
  source = "./modules/oke-region"

  providers = {
    oci = oci.primary
  }

  region_role                  = "primary"
  region_short_name            = local.primary_region_short_name
  region_name                  = var.primary_region
  name_prefix                  = var.name_prefix
  compartment_ocid             = var.compartment_ocid
  kubernetes_version           = var.kubernetes_version
  cluster_type                 = var.cluster_type
  node_count                   = var.node_count
  node_shape                   = var.node_shape
  node_shape_config            = local.node_shape_config
  ssh_public_key               = local.ssh_public_key
  node_image_id                = local.node_image_id
  node_boot_volume_size_in_gbs = var.node_boot_volume_size_in_gbs
  node_pool_os_type            = var.node_pool_os_type
  node_pool_os_arch            = var.node_pool_os_arch
  max_pods_per_node            = var.max_pods_per_node
  kube_api_allowed_cidrs       = var.kube_api_allowed_cidrs
  load_balancer_ingress_cidrs  = var.load_balancer_ingress_cidrs
  load_balancer_ingress_ports  = var.load_balancer_ingress_ports
  enable_file_storage          = true
  vcn_cidr                     = var.primary_vcn_cidr
  remote_vcn_cidr              = var.standby_vcn_cidr
  remote_worker_subnet_cidr    = var.standby_worker_subnet_cidr
  remote_pod_subnet_cidr       = var.standby_pod_subnet_cidr
  api_endpoint_subnet_cidr     = var.primary_api_endpoint_subnet_cidr
  worker_subnet_cidr           = var.primary_worker_subnet_cidr
  pod_subnet_cidr              = var.primary_pod_subnet_cidr
  load_balancer_subnet_cidr    = var.primary_load_balancer_subnet_cidr
  freeform_tags                = var.freeform_tags
}

module "standby_oke" {
  source = "./modules/oke-region"

  providers = {
    oci = oci.standby
  }

  region_role                  = "standby"
  region_short_name            = local.standby_region_short_name
  region_name                  = var.standby_region
  name_prefix                  = var.name_prefix
  compartment_ocid             = var.compartment_ocid
  kubernetes_version           = var.kubernetes_version
  cluster_type                 = var.cluster_type
  node_count                   = var.node_count
  node_shape                   = var.node_shape
  node_shape_config            = local.node_shape_config
  ssh_public_key               = local.ssh_public_key
  node_image_id                = local.node_image_id
  node_boot_volume_size_in_gbs = var.node_boot_volume_size_in_gbs
  node_pool_os_type            = var.node_pool_os_type
  node_pool_os_arch            = var.node_pool_os_arch
  max_pods_per_node            = var.max_pods_per_node
  kube_api_allowed_cidrs       = var.kube_api_allowed_cidrs
  load_balancer_ingress_cidrs  = var.load_balancer_ingress_cidrs
  load_balancer_ingress_ports  = var.load_balancer_ingress_ports
  vcn_cidr                     = var.standby_vcn_cidr
  remote_vcn_cidr              = var.primary_vcn_cidr
  remote_worker_subnet_cidr    = var.primary_worker_subnet_cidr
  remote_pod_subnet_cidr       = var.primary_pod_subnet_cidr
  api_endpoint_subnet_cidr     = var.standby_api_endpoint_subnet_cidr
  worker_subnet_cidr           = var.standby_worker_subnet_cidr
  pod_subnet_cidr              = var.standby_pod_subnet_cidr
  load_balancer_subnet_cidr    = var.standby_load_balancer_subnet_cidr
  freeform_tags                = var.freeform_tags
}
