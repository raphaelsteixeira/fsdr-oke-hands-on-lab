variable "compartment_ocid" {
  description = "OCID of the compartment where both regional OKE environments will be created."
  type        = string
}

variable "primary_region" {
  description = "OCI region identifier for the primary OKE cluster, for example eu-frankfurt-1."
  type        = string
}

variable "standby_region" {
  description = "OCI region identifier for the standby OKE cluster, for example eu-madrid-1."
  type        = string
}

variable "primary_region_short_name" {
  description = "Optional short region label used in primary-region resource names. If null, Terraform uses a known OCI region key or derives one from primary_region."
  type        = string
  default     = null

  validation {
    condition     = var.primary_region_short_name == null || var.primary_region_short_name == "" || can(regex("^[A-Za-z0-9-]+$", var.primary_region_short_name))
    error_message = "primary_region_short_name can be empty or contain only letters, numbers, and hyphens."
  }
}

variable "standby_region_short_name" {
  description = "Optional short region label used in standby-region resource names. If null, Terraform uses a known OCI region key or derives one from standby_region."
  type        = string
  default     = null

  validation {
    condition     = var.standby_region_short_name == null || var.standby_region_short_name == "" || can(regex("^[A-Za-z0-9-]+$", var.standby_region_short_name))
    error_message = "standby_region_short_name can be empty or contain only letters, numbers, and hyphens."
  }
}

variable "name_prefix" {
  description = "Prefix used for all resource display names."
  type        = string
  default     = "oke-dr-lab"
}

variable "home_region" {
  description = "OCI tenancy home region used for IAM resources such as dynamic groups and policies. Defaults to primary_region."
  type        = string
  default     = null
}

variable "auth" {
  description = "Optional OCI provider authentication mode for local runs. Leave null for OCI Resource Manager."
  type        = string
  default     = null
}

variable "config_file_profile" {
  description = "Optional OCI config profile to use for local runs. Leave null for OCI Resource Manager."
  type        = string
  default     = null
}

variable "oci_config_file_path" {
  description = "Optional OCI CLI config file path used to infer the tenancy OCID for FSDR IAM when fsdr_iam_tenancy_ocid and tenancy_ocid are not set."
  type        = string
  default     = "~/.oci/config"
}

variable "tenancy_ocid" {
  description = "Optional tenancy OCID for provider authentication. Can be omitted when it is already present in ~/.oci/config or environment variables."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_fsdr_iam" {
  description = "Create the Full Stack DR resource-principal dynamic group and policies."
  type        = bool
  default     = true
}

variable "fsdr_iam_tenancy_ocid" {
  description = "Tenancy/root compartment OCID used to create the FSDR dynamic group and tenancy-attached policy. Defaults to tenancy_ocid when set."
  type        = string
  default     = null
}

variable "user_ocid" {
  description = "Optional user OCID for API key authentication."
  type        = string
  default     = null
  sensitive   = true
}

variable "fingerprint" {
  description = "Optional API key fingerprint for API key authentication."
  type        = string
  default     = null
  sensitive   = true
}

variable "private_key_path" {
  description = "Optional API private key path for API key authentication."
  type        = string
  default     = null
  sensitive   = true
}

variable "private_key_password" {
  description = "Optional API private key passphrase."
  type        = string
  default     = null
  sensitive   = true
}

variable "kubernetes_version" {
  description = "OKE Kubernetes version for the cluster control plane and worker nodes."
  type        = string
  default     = "v1.35.2"
  nullable    = false

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be a full patch version such as v1.35.2."
  }
}

variable "cluster_type" {
  description = "OKE cluster type."
  type        = string
  default     = "ENHANCED_CLUSTER"

  validation {
    condition     = contains(["BASIC_CLUSTER", "ENHANCED_CLUSTER"], var.cluster_type)
    error_message = "cluster_type must be either BASIC_CLUSTER or ENHANCED_CLUSTER."
  }
}

variable "node_count" {
  description = "Number of worker nodes to create in each regional OKE node pool."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "node_shape" {
  description = "Compute shape for OKE worker nodes."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "node_ocpus" {
  description = "OCPUs for each worker node when node_shape is a Flex shape."
  type        = number
  default     = 1

  validation {
    condition     = var.node_ocpus > 0
    error_message = "node_ocpus must be greater than 0."
  }
}

variable "node_memory_in_gbs" {
  description = "Memory in GB for each worker node when node_shape is a Flex shape."
  type        = number
  default     = 16

  validation {
    condition     = var.node_memory_in_gbs > 0
    error_message = "node_memory_in_gbs must be greater than 0."
  }
}

variable "node_shape_config" {
  description = "Optional advanced Flex shape sizing override. Leave null to use node_ocpus and node_memory_in_gbs."
  type = object({
    ocpus         = number
    memory_in_gbs = number
  })
  default  = null
  nullable = true
}

variable "ssh_public_key" {
  description = "Optional SSH public key to inject into worker nodes."
  type        = string
  default     = null
}

variable "node_image_id" {
  description = "Optional custom worker node image OCID. Leave null to select a compatible OKE worker image from OCI node pool options."
  type        = string
  default     = null
}

variable "node_boot_volume_size_in_gbs" {
  description = "Boot volume size for worker nodes."
  type        = number
  default     = 50
}

variable "node_pool_os_type" {
  description = "Worker node OS type used when selecting a default OKE image from OCI node pool options."
  type        = string
  default     = "OL8"

  validation {
    condition     = contains(["OL8", "UBUNTU"], var.node_pool_os_type)
    error_message = "node_pool_os_type must be one of: OL8, UBUNTU."
  }
}

variable "node_pool_os_arch" {
  description = "Worker node OS architecture used when selecting a default OKE image from OCI node pool options."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "AARCH64"], var.node_pool_os_arch)
    error_message = "node_pool_os_arch must be one of: X86_64, AARCH64."
  }
}

variable "max_pods_per_node" {
  description = "Maximum pods per worker node when using OCI VCN-native pod networking."
  type        = number
  default     = 31
}

variable "kube_api_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint on TCP/6443. Each regional VCN CIDR is always allowed."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "load_balancer_ingress_cidrs" {
  description = "CIDR blocks allowed to reach public Kubernetes service load balancers."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "load_balancer_ingress_ports" {
  description = "TCP ports allowed into the public load balancer subnet."
  type        = list(number)
  default     = [80, 443]
}

variable "primary_vcn_cidr" {
  description = "VCN CIDR for the primary region."
  type        = string
  default     = "10.10.0.0/16"
}

variable "primary_api_endpoint_subnet_cidr" {
  description = "Kubernetes API endpoint subnet CIDR for the primary region."
  type        = string
  default     = "10.10.0.0/28"
}

variable "primary_worker_subnet_cidr" {
  description = "Private worker node subnet CIDR for the primary region."
  type        = string
  default     = "10.10.10.0/24"
}

variable "primary_pod_subnet_cidr" {
  description = "Private pod subnet CIDR for the primary region."
  type        = string
  default     = "10.10.20.0/22"
}

variable "primary_load_balancer_subnet_cidr" {
  description = "Public load balancer subnet CIDR for the primary region."
  type        = string
  default     = "10.10.30.0/24"
}

variable "standby_vcn_cidr" {
  description = "VCN CIDR for the standby region."
  type        = string
  default     = "10.20.0.0/16"
}

variable "standby_api_endpoint_subnet_cidr" {
  description = "Kubernetes API endpoint subnet CIDR for the standby region."
  type        = string
  default     = "10.20.0.0/28"
}

variable "standby_worker_subnet_cidr" {
  description = "Private worker node subnet CIDR for the standby region."
  type        = string
  default     = "10.20.10.0/24"
}

variable "standby_pod_subnet_cidr" {
  description = "Private pod subnet CIDR for the standby region."
  type        = string
  default     = "10.20.20.0/22"
}

variable "standby_load_balancer_subnet_cidr" {
  description = "Public load balancer subnet CIDR for the standby region."
  type        = string
  default     = "10.20.30.0/24"
}

variable "freeform_tags" {
  description = "Freeform tags applied to all created resources."
  type        = map(string)
  default     = {}
}
