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
    api_endpoint   = oci_core_network_security_group.api_endpoint.id
    workers        = oci_core_network_security_group.workers.id
    pods           = oci_core_network_security_group.pods.id
    load_balancers = oci_core_network_security_group.load_balancers.id
    file_storage   = try(oci_core_network_security_group.file_storage[0].id, null)
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

output "file_storage" {
  description = "Regional File Storage mount target details when enabled."
  value = local.enable_file_storage_mount_target ? {
    file_system_id      = try(oci_file_storage_file_system.this[0].id, null)
    file_system_name    = try(oci_file_storage_file_system.this[0].display_name, null)
    mount_target_id     = oci_file_storage_mount_target.this[0].id
    mount_target_name   = oci_file_storage_mount_target.this[0].display_name
    mount_target_ip     = oci_file_storage_mount_target.this[0].ip_address
    mount_target_subnet = oci_core_subnet.workers.id
    export_id           = try(oci_file_storage_export.this[0].id, null)
    export_path         = try(oci_file_storage_export.this[0].path, null)
    mount_command       = try("sudo mount -t nfs ${oci_file_storage_mount_target.this[0].ip_address}:${oci_file_storage_export.this[0].path} /mnt/oke", null)
    nsg_id              = oci_core_network_security_group.file_storage[0].id
  } : null
}
