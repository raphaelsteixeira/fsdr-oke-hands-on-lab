output "cluster_id" {
  description = "OKE cluster OCID."
  value       = oci_containerengine_cluster.this.id
}

output "region_short_name" {
  description = "Short region label used in OCI resource names."
  value       = local.region_name_label
}

output "cluster_name" {
  description = "OKE cluster name."
  value       = oci_containerengine_cluster.this.name
}

output "cluster_endpoints" {
  description = "OKE cluster endpoint details."
  value       = oci_containerengine_cluster.this.endpoints
}

output "node_pool_id" {
  description = "OKE node pool OCID."
  value       = oci_containerengine_node_pool.this.id
}

output "vcn_id" {
  description = "VCN OCID."
  value       = oci_core_vcn.this.id
}

output "drg" {
  description = "DRG and VCN attachment created for regional peering."
  value = {
    id            = oci_core_drg.this.id
    name          = oci_core_drg.this.display_name
    attachment_id = oci_core_drg_attachment.vcn.id
  }
}

output "subnet_ids" {
  description = "Subnets created for the regional OKE topology."
  value = {
    api_endpoint   = oci_core_subnet.api_endpoint.id
    workers        = oci_core_subnet.workers.id
    pods           = oci_core_subnet.pods.id
    load_balancers = oci_core_subnet.load_balancers.id
  }
}

output "nsg_ids" {
  description = "Network Security Groups created for the regional OKE topology."
  value = {
    api_endpoint                    = oci_core_network_security_group.api_endpoint.id
    workers                         = oci_core_network_security_group.workers.id
    pods                            = oci_core_network_security_group.pods.id
    load_balancers                  = oci_core_network_security_group.load_balancers.id
    object_storage_private_endpoint = oci_core_network_security_group.object_storage_private_endpoint.id
    file_storage                    = try(oci_core_network_security_group.file_storage[0].id, null)
  }
}

output "object_storage_buckets" {
  description = "Object Storage buckets created for regional FSDR logs and OKE backup."
  value = {
    for key, bucket in oci_objectstorage_bucket.this : key => {
      id        = bucket.id
      name      = bucket.name
      namespace = bucket.namespace
    }
  }
}

output "object_storage_private_endpoint" {
  description = "Object Storage private endpoint scoped to the regional buckets and allowed worker subnet CIDRs."
  value = {
    id                         = oci_objectstorage_private_endpoint.this.id
    name                       = oci_objectstorage_private_endpoint.this.name
    namespace                  = oci_objectstorage_private_endpoint.this.namespace
    prefix                     = oci_objectstorage_private_endpoint.this.prefix
    private_endpoint_ip        = oci_objectstorage_private_endpoint.this.private_endpoint_ip
    subnet_id                  = oci_objectstorage_private_endpoint.this.subnet_id
    nsg_id                     = oci_core_network_security_group.object_storage_private_endpoint.id
    allowed_source_cidr        = var.worker_subnet_cidr
    allowed_source_cidrs       = local.object_storage_private_endpoint_source_cidrs
    pod_source_cidr            = var.pod_subnet_cidr
    remote_worker_source_cidr  = var.remote_worker_subnet_cidr
    remote_pod_source_cidr     = var.remote_pod_subnet_cidr
    routed_remote_vcn_cidr     = var.remote_vcn_cidr
    routed_remote_subnet_cidrs = local.remote_private_route_cidrs
    routed_remote_worker_cidr  = var.remote_worker_subnet_cidr
    routed_remote_pod_cidr     = var.remote_pod_subnet_cidr
    access_target_bucket_names = [for bucket in oci_objectstorage_bucket.this : bucket.name]
    private_endpoint_fqdn      = "${oci_objectstorage_private_endpoint.this.prefix}-${oci_objectstorage_private_endpoint.this.namespace}.private.objectstorage.${var.region_name}.oci.customer-oci.com"
    fqdns                      = oci_objectstorage_private_endpoint.this.fqdns
  }
}

output "file_storage" {
  description = "Primary-region File Storage details when enabled."
  value = try({
    file_system_id      = oci_file_storage_file_system.this[0].id
    file_system_name    = oci_file_storage_file_system.this[0].display_name
    mount_target_id     = oci_file_storage_mount_target.this[0].id
    mount_target_name   = oci_file_storage_mount_target.this[0].display_name
    mount_target_ip     = oci_file_storage_mount_target.this[0].ip_address
    mount_target_subnet = oci_core_subnet.workers.id
    export_id           = oci_file_storage_export.this[0].id
    export_path         = oci_file_storage_export.this[0].path
    mount_command       = "sudo mount -t nfs ${oci_file_storage_mount_target.this[0].ip_address}:${oci_file_storage_export.this[0].path} /mnt/oke"
    nsg_id              = oci_core_network_security_group.file_storage[0].id
  }, null)
}
