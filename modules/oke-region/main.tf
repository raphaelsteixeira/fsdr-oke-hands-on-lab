data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_objectstorage_namespace" "this" {}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

data "oci_containerengine_node_pool_option" "this" {
  count = var.node_image_id == null ? 1 : 0

  compartment_id        = var.compartment_ocid
  node_pool_k8s_version = local.effective_kubernetes_version
  node_pool_option_id   = oci_containerengine_cluster.this.id
  node_pool_os_arch     = var.node_pool_os_arch
  node_pool_os_type     = var.node_pool_os_type
}

locals {
  region_name_label = replace(lower(var.region_short_name), "/[^a-z0-9-]/", "-")
  resource_prefix   = "${var.name_prefix}-${local.region_name_label}"
  bucket_prefix     = replace(lower(local.resource_prefix), "/[^a-z0-9-]/", "-")
  # VCN DNS labels are immutable in OCI; keep the existing role-based label to avoid replacing the network.
  dns_label                    = substr("oke${replace(lower("${var.name_prefix}${var.region_role}"), "/[^a-z0-9]/", "")}", 0, 15)
  common_tags                  = merge(var.freeform_tags, { lab = var.name_prefix, region_role = var.region_role, region_short_name = local.region_name_label })
  effective_kubernetes_version = startswith(var.kubernetes_version, "v") ? var.kubernetes_version : "v${var.kubernetes_version}"
  node_pool_option_sources     = var.node_image_id == null ? coalesce(data.oci_containerengine_node_pool_option.this[0].sources, []) : []
  node_pool_supported_shapes   = var.node_image_id == null ? coalesce(data.oci_containerengine_node_pool_option.this[0].shapes, []) : []
  node_shape_uses_gpu_image    = strcontains(lower(var.node_shape), "gpu")
  default_node_image_ids = [
    for source in local.node_pool_option_sources : source.image_id
    if source.source_type == "IMAGE" && strcontains(lower(source.source_name), "gpu") == local.node_shape_uses_gpu_image
  ]
  selected_node_image_id = var.node_image_id != null ? var.node_image_id : try(local.default_node_image_ids[0], null)

  api_allowed_cidrs = distinct(concat([var.vcn_cidr, var.remote_vcn_cidr], var.kube_api_allowed_cidrs))
  api_endpoint_registration_ingress_rules = flatten([
    for source in [var.worker_subnet_cidr, var.pod_subnet_cidr] : [
      for port in [6443, 12250] : {
        source = source
        port   = port
      }
    ]
  ])
  load_balancer_ingress_rules = flatten([
    for cidr in var.load_balancer_ingress_cidrs : [
      for port in var.load_balancer_ingress_ports : {
        cidr = cidr
        port = port
      }
    ]
  ])
  file_storage_nfs_ingress_rules = flatten([
    for rule_set in [
      {
        protocol_number = "6"
        protocol_name   = "tcp"
        ports           = [111, 2048, 2049, 2050, 20048]
      },
      {
        protocol_number = "17"
        protocol_name   = "udp"
        ports           = [111, 2048, 20048]
      }
      ] : [
      for port in rule_set.ports : {
        protocol_number = rule_set.protocol_number
        protocol_name   = rule_set.protocol_name
        port            = port
      }
    ]
  ])
  file_storage_hostname_label            = substr("fss${replace(lower("${var.name_prefix}${local.region_name_label}"), "/[^a-z0-9]/", "")}", 0, 15)
  object_storage_private_endpoint_prefix = substr("ospe${replace(lower("${var.name_prefix}${local.region_name_label}"), "/[^a-z0-9]/", "")}", 0, 15)
  object_storage_private_endpoint_source_cidrs = distinct([
    var.worker_subnet_cidr,
    var.pod_subnet_cidr,
    var.remote_worker_subnet_cidr,
    var.remote_pod_subnet_cidr
  ])
  remote_private_route_cidrs = tolist(setsubtract(
    toset([var.remote_worker_subnet_cidr, var.remote_pod_subnet_cidr]),
    toset([var.remote_vcn_cidr])
  ))
  object_storage_buckets = {
    fsdr_logs = {
      name        = "${local.bucket_prefix}-fsdr-logs"
      description = "FSDR logs bucket"
      versioning  = "Disabled"
    }
    oke_backup = {
      name        = "${local.bucket_prefix}-oke-backup"
      description = "OKE backup bucket"
      versioning  = "Enabled"
    }
  }
}

resource "oci_objectstorage_bucket" "this" {
  for_each = local.object_storage_buckets

  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = each.value.name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = each.value.versioning
  freeform_tags  = merge(local.common_tags, { purpose = each.key, description = each.value.description })
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.resource_prefix}-vcn"
  dns_label      = local.dns_label
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-igw"
  enabled        = true
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-nat"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-sgw"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

resource "oci_core_drg" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-drg"
  freeform_tags  = local.common_tags
}

resource "oci_core_drg_attachment" "vcn" {
  drg_id       = oci_core_drg.this.id
  display_name = "${local.resource_prefix}-vcn-drg-attachment"
  freeform_tags = merge(local.common_tags, {
    attachment_type = "vcn"
  })

  network_details {
    id   = oci_core_vcn.this.id
    type = "VCN"
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-public-rt"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }

  route_rules {
    destination       = var.remote_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-private-rt"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }

  route_rules {
    destination       = var.remote_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.this.id
  }

  dynamic "route_rules" {
    for_each = toset(local.remote_private_route_cidrs)

    content {
      destination       = route_rules.value
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_drg.this.id
    }
  }
}

resource "oci_core_network_security_group" "api_endpoint" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-api-nsg"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_network_security_group" "workers" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-workers-nsg"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_network_security_group" "pods" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-pods-nsg"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_network_security_group" "load_balancers" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-lb-nsg"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_network_security_group" "object_storage_private_endpoint" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-object-storage-pe-nsg"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_network_security_group" "file_storage" {
  count = var.enable_file_storage ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-fss-nsg"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_security_list" "empty" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.resource_prefix}-empty-required-sl"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_network_security_group_security_rule" "api_endpoint_egress_all" {
  network_security_group_id = oci_core_network_security_group.api_endpoint.id
  description               = "Allow OKE API endpoint egress for cluster control-plane communication."
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "api_endpoint_ingress_kubernetes" {
  for_each = toset(local.api_allowed_cidrs)

  network_security_group_id = oci_core_network_security_group.api_endpoint.id
  description               = "Allow Kubernetes API access on TCP/6443."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_endpoint_ingress_registration" {
  for_each = {
    for rule in local.api_endpoint_registration_ingress_rules : "${rule.source}-${rule.port}" => rule
  }

  network_security_group_id = oci_core_network_security_group.api_endpoint.id
  description               = "Allow worker and pod registration traffic to the OKE API endpoint."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value.source
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_endpoint_ingress_path_discovery" {
  network_security_group_id = oci_core_network_security_group.api_endpoint.id
  description               = "Allow ICMP fragmentation-needed messages for path MTU discovery."
  direction                 = "INGRESS"
  protocol                  = "1"
  source                    = var.worker_subnet_cidr
  source_type               = "CIDR_BLOCK"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "workers_egress_all" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Allow worker node egress to OCI services, the API endpoint, and pods."
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_vcn" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Allow required traffic from the cluster VCN to worker nodes."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_remote_vcn" {
  count = var.remote_vcn_cidr == var.vcn_cidr ? 0 : 1

  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Allow required traffic from the peered remote VCN to worker nodes."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.remote_vcn_cidr
  source_type               = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_api_endpoint_kubelet" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Allow OKE API endpoint to reach kubelet on worker nodes."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.api_endpoint_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_path_discovery" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Allow ICMP fragmentation-needed messages for path MTU discovery."
  direction                 = "INGRESS"
  protocol                  = "1"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "pods_egress_all" {
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Allow pod egress to OCI services, the API endpoint, and workers."
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "pods_ingress_vcn" {
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Allow required traffic from the cluster VCN to pods."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "pods_ingress_remote_vcn" {
  count = var.remote_vcn_cidr == var.vcn_cidr ? 0 : 1

  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Allow required traffic from the peered remote VCN to pods."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.remote_vcn_cidr
  source_type               = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "load_balancers_egress_all" {
  network_security_group_id = oci_core_network_security_group.load_balancers.id
  description               = "Allow load balancer egress to worker backends."
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "load_balancers_ingress" {
  for_each = {
    for rule in local.load_balancer_ingress_rules : "${rule.cidr}-${rule.port}" => rule
  }

  network_security_group_id = oci_core_network_security_group.load_balancers.id
  description               = "Allow public ingress to Kubernetes service load balancers."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value.cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "object_storage_private_endpoint_ingress_https" {
  network_security_group_id = oci_core_network_security_group.object_storage_private_endpoint.id
  description               = "Allow worker nodes to access Object Storage private endpoint on HTTPS."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.worker_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "object_storage_private_endpoint_ingress_pod_https" {
  count = var.pod_subnet_cidr == var.worker_subnet_cidr ? 0 : 1

  network_security_group_id = oci_core_network_security_group.object_storage_private_endpoint.id
  description               = "Allow pods to access Object Storage private endpoint on HTTPS."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.pod_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "object_storage_private_endpoint_ingress_remote_worker_https" {
  count = contains([var.worker_subnet_cidr, var.pod_subnet_cidr], var.remote_worker_subnet_cidr) ? 0 : 1

  network_security_group_id = oci_core_network_security_group.object_storage_private_endpoint.id
  description               = "Allow peered remote worker nodes to access Object Storage private endpoint on HTTPS."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.remote_worker_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "object_storage_private_endpoint_ingress_remote_pod_https" {
  count = contains([var.worker_subnet_cidr, var.pod_subnet_cidr, var.remote_worker_subnet_cidr], var.remote_pod_subnet_cidr) ? 0 : 1

  network_security_group_id = oci_core_network_security_group.object_storage_private_endpoint.id
  description               = "Allow peered remote pods to access Object Storage private endpoint on HTTPS."
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.remote_pod_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "file_storage_ingress_nfs" {
  for_each = var.enable_file_storage ? {
    for rule in local.file_storage_nfs_ingress_rules : "${rule.protocol_name}-${rule.port}" => rule
  } : {}

  network_security_group_id = oci_core_network_security_group.file_storage[0].id
  description               = "Allow worker nodes to access File Storage NFS on ${upper(each.value.protocol_name)}/${each.value.port}."
  direction                 = "INGRESS"
  protocol                  = each.value.protocol_number
  source                    = var.worker_subnet_cidr
  source_type               = "CIDR_BLOCK"

  dynamic "tcp_options" {
    for_each = each.value.protocol_name == "tcp" ? [each.value.port] : []

    content {
      destination_port_range {
        min = tcp_options.value
        max = tcp_options.value
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol_name == "udp" ? [each.value.port] : []

    content {
      destination_port_range {
        min = udp_options.value
        max = udp_options.value
      }
    }
  }
}

resource "oci_core_subnet" "api_endpoint" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.api_endpoint_subnet_cidr
  display_name               = "${local.resource_prefix}-api-endpoint-subnet"
  dns_label                  = "api"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.empty.id]
  vcn_id                     = oci_core_vcn.this.id
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "workers" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.worker_subnet_cidr
  display_name               = "${local.resource_prefix}-workers-subnet"
  dns_label                  = "workers"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.empty.id]
  vcn_id                     = oci_core_vcn.this.id
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "pods" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.pod_subnet_cidr
  display_name               = "${local.resource_prefix}-pods-subnet"
  dns_label                  = "pods"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.empty.id]
  vcn_id                     = oci_core_vcn.this.id
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "load_balancers" {
  compartment_id             = var.compartment_ocid
  cidr_block                 = var.load_balancer_subnet_cidr
  display_name               = "${local.resource_prefix}-lb-subnet"
  dns_label                  = "lb"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.empty.id]
  vcn_id                     = oci_core_vcn.this.id
  freeform_tags              = local.common_tags
}

resource "oci_objectstorage_private_endpoint" "this" {
  compartment_id = var.compartment_ocid
  name           = "${local.resource_prefix}-object-storage-pe"
  namespace      = data.oci_objectstorage_namespace.this.namespace
  prefix         = local.object_storage_private_endpoint_prefix
  subnet_id      = oci_core_subnet.workers.id
  nsg_ids        = [oci_core_network_security_group.object_storage_private_endpoint.id]
  freeform_tags  = local.common_tags

  dynamic "access_targets" {
    for_each = oci_objectstorage_bucket.this

    content {
      bucket         = access_targets.value.name
      compartment_id = var.compartment_ocid
      namespace      = access_targets.value.namespace
    }
  }
}

resource "oci_file_storage_file_system" "this" {
  count = var.enable_file_storage ? 1 : 0

  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${local.resource_prefix}-fss"
  freeform_tags       = local.common_tags
}

resource "oci_file_storage_mount_target" "this" {
  count = var.enable_file_storage ? 1 : 0

  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${local.resource_prefix}-fss-mt"
  hostname_label      = local.file_storage_hostname_label
  subnet_id           = oci_core_subnet.workers.id
  nsg_ids             = [oci_core_network_security_group.file_storage[0].id]
  freeform_tags       = local.common_tags
}

resource "oci_file_storage_export" "this" {
  count = var.enable_file_storage ? 1 : 0

  export_set_id  = oci_file_storage_mount_target.this[0].export_set_id
  file_system_id = oci_file_storage_file_system.this[0].id
  path           = var.file_storage_export_path

  export_options {
    source                         = var.worker_subnet_cidr
    access                         = "READ_WRITE"
    identity_squash                = "NONE"
    require_privileged_source_port = false
  }
}

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.effective_kubernetes_version
  name               = "${local.resource_prefix}-oke"
  type               = var.cluster_type
  vcn_id             = oci_core_vcn.this.id
  freeform_tags      = local.common_tags

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = true
    nsg_ids              = [oci_core_network_security_group.api_endpoint.id]
    subnet_id            = oci_core_subnet.api_endpoint.id
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.load_balancers.id]

    service_lb_config {
      backend_nsg_ids = [oci_core_network_security_group.workers.id]
    }
  }
}

resource "oci_containerengine_node_pool" "this" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.effective_kubernetes_version
  name               = "${local.resource_prefix}-pool"
  node_shape         = var.node_shape
  ssh_public_key     = var.ssh_public_key
  freeform_tags      = local.common_tags

  dynamic "node_shape_config" {
    for_each = var.node_shape_config == null ? [] : [var.node_shape_config]

    content {
      ocpus         = node_shape_config.value.ocpus
      memory_in_gbs = node_shape_config.value.memory_in_gbs
    }
  }

  node_config_details {
    nsg_ids = [oci_core_network_security_group.workers.id]
    size    = var.node_count

    dynamic "placement_configs" {
      for_each = data.oci_identity_availability_domains.ads.availability_domains

      content {
        availability_domain = placement_configs.value.name
        subnet_id           = oci_core_subnet.workers.id
      }
    }

    node_pool_pod_network_option_details {
      cni_type          = "OCI_VCN_IP_NATIVE"
      max_pods_per_node = var.max_pods_per_node
      pod_nsg_ids       = [oci_core_network_security_group.pods.id]
      pod_subnet_ids    = [oci_core_subnet.pods.id]
    }
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.selected_node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_size_in_gbs
  }

  lifecycle {
    precondition {
      condition     = local.selected_node_image_id != null
      error_message = "OCI did not return a compatible ${var.node_pool_os_type}/${var.node_pool_os_arch} OKE worker image for ${local.effective_kubernetes_version}. Set node_image_id to a valid image OCID for this region, or choose a different Kubernetes version/OS combination."
    }

    precondition {
      condition     = var.node_image_id != null || contains(local.node_pool_supported_shapes, var.node_shape)
      error_message = "OCI node pool options for ${local.effective_kubernetes_version} in this region do not list ${var.node_shape} as a supported shape for ${var.node_pool_os_type}/${var.node_pool_os_arch}."
    }
  }
}
