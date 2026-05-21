variable "region_role" {
  description = "Logical role label for this regional deployment, for example primary or standby."
  type        = string
}

variable "region_short_name" {
  description = "Short region label used in OCI resource names, for example fra or mad."
  type        = string
}

variable "region_name" {
  description = "OCI region identifier for this regional deployment."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for all resource display names."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment where this regional OKE environment will be created."
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block for this region's VCN."
  type        = string
}

variable "api_endpoint_subnet_cidr" {
  description = "CIDR block for the Kubernetes API endpoint subnet."
  type        = string
}

variable "worker_subnet_cidr" {
  description = "CIDR block for the private worker node subnet."
  type        = string
}

variable "pod_subnet_cidr" {
  description = "CIDR block for the private pod subnet."
  type        = string
}

variable "load_balancer_subnet_cidr" {
  description = "CIDR block for the public service load balancer subnet."
  type        = string
}

variable "kubernetes_version" {
  description = "OKE Kubernetes version for the cluster control plane and worker nodes."
  type        = string
  nullable    = false
}

variable "cluster_type" {
  description = "OKE cluster type."
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes in this regional node pool."
  type        = number
}

variable "node_shape" {
  description = "Compute shape for worker nodes."
  type        = string
}

variable "node_shape_config" {
  description = "Flex shape sizing. Set to null when using a fixed-size non-flex shape."
  type = object({
    ocpus         = number
    memory_in_gbs = number
  })
  nullable = true
}

variable "ssh_public_key" {
  description = "Optional SSH public key to inject into worker nodes."
  type        = string
  default     = null
}

variable "node_image_id" {
  description = "Optional custom worker node image OCID."
  type        = string
  default     = null
}

variable "node_boot_volume_size_in_gbs" {
  description = "Boot volume size for worker nodes."
  type        = number
}

variable "node_pool_os_type" {
  description = "Worker node OS type used when selecting a default OKE image from OCI node pool options."
  type        = string
}

variable "node_pool_os_arch" {
  description = "Worker node OS architecture used when selecting a default OKE image from OCI node pool options."
  type        = string
}

variable "max_pods_per_node" {
  description = "Maximum pods per node for OCI VCN-native pod networking."
  type        = number
}

variable "kube_api_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint on TCP/6443."
  type        = list(string)
}

variable "load_balancer_ingress_cidrs" {
  description = "CIDR blocks allowed to reach public Kubernetes service load balancers."
  type        = list(string)
}

variable "load_balancer_ingress_ports" {
  description = "TCP ports allowed into the public load balancer subnet."
  type        = list(number)
}

variable "enable_file_storage" {
  description = "Whether to create an OCI File Storage file system, mount target, and export in this region."
  type        = bool
  default     = false
}

variable "enable_file_storage_mount_target" {
  description = "Whether to create an OCI File Storage mount target and NSG in this region."
  type        = bool
  default     = false
}

variable "file_storage_export_path" {
  description = "Export path for the regional OCI File Storage file system."
  type        = string
  default     = "/oke"

  validation {
    condition     = startswith(var.file_storage_export_path, "/")
    error_message = "file_storage_export_path must start with '/'."
  }
}

variable "freeform_tags" {
  description = "Freeform tags applied to all created resources."
  type        = map(string)
}
