locals {
  oci_config_file_path_input    = try(trimspace(var.oci_config_file_path), "")
  oci_config_profile_name_input = try(trimspace(var.config_file_profile), "")
  fsdr_iam_tenancy_ocid_input   = try(trimspace(var.fsdr_iam_tenancy_ocid), "")
  provider_tenancy_ocid_input   = try(trimspace(nonsensitive(var.tenancy_ocid)), "")

  oci_config_file_path    = local.oci_config_file_path_input != "" ? pathexpand(local.oci_config_file_path_input) : null
  oci_config_profile_name = local.oci_config_profile_name_input != "" ? local.oci_config_profile_name_input : "DEFAULT"
  oci_config_text         = local.oci_config_file_path != null && fileexists(local.oci_config_file_path) ? file(local.oci_config_file_path) : ""
  oci_config_header       = "[${local.oci_config_profile_name}]"
  oci_config_sections     = split(local.oci_config_header, local.oci_config_text)
  oci_config_profile      = length(local.oci_config_sections) > 1 ? split("\n[", local.oci_config_sections[1])[0] : ""
  oci_config_tenancy      = try(trimspace(regex("(?m)^\\s*tenancy\\s*=\\s*([^\\s#]+)", local.oci_config_profile)[0]), "")

  fsdr_iam_tenancy_ocid = try(coalesce(
    local.fsdr_iam_tenancy_ocid_input != "" ? local.fsdr_iam_tenancy_ocid_input : null,
    local.provider_tenancy_ocid_input != "" ? local.provider_tenancy_ocid_input : null,
    local.oci_config_tenancy != "" ? local.oci_config_tenancy : null
  ), null)

  fsdr_iam_name_prefix     = lower(replace(var.name_prefix, "/[^A-Za-z0-9_.-]/", "-"))
  fsdr_dynamic_group_name  = "${local.fsdr_iam_name_prefix}-fsdr-resource-principals"
  fsdr_policy_name         = "${local.fsdr_iam_name_prefix}-fsdr-resource-principal-policy"
  fsdr_policy_description  = "Allows OCI Full Stack DR resource principals to orchestrate the lab stack in the deployment compartment."
  fsdr_dynamic_group_rules = "Any {All {resource.type = 'drprotectiongroup', resource.compartment.id = '${var.compartment_ocid}'}, instance.compartment.id = '${var.compartment_ocid}', All {resource.type = 'computecontainerinstance', resource.compartment.id = '${var.compartment_ocid}'}}"

  fsdr_policy_permissions = [
    "manage disaster-recovery-family in compartment id ${var.compartment_ocid}",
    "manage object-family in compartment id ${var.compartment_ocid}",
    "manage objects in compartment id ${var.compartment_ocid}",
    "manage instance-family in compartment id ${var.compartment_ocid}",
    "manage instance-agent-command-execution-family in compartment id ${var.compartment_ocid}",
    "manage instance-agent-command-family in compartment id ${var.compartment_ocid}",
    "manage instance-agent-plugins in compartment id ${var.compartment_ocid}",
    "manage virtual-network-family in compartment id ${var.compartment_ocid}",
    "manage volume-family in compartment id ${var.compartment_ocid}",
    "manage file-family in compartment id ${var.compartment_ocid}",
    "manage load-balancers in compartment id ${var.compartment_ocid}",
    "manage network-load-balancers in compartment id ${var.compartment_ocid}",
    "manage cluster-family in compartment id ${var.compartment_ocid}",
    "manage cluster-virtualnode-pools in compartment id ${var.compartment_ocid}",
    "manage compute-container-family in compartment id ${var.compartment_ocid}",
    "use tag-namespaces in tenancy",
    "use instance-images in tenancy",
    "read all-resources in tenancy",
  ]
}

resource "terraform_data" "fsdr_iam_tenancy_required" {
  count = var.enable_fsdr_iam && local.fsdr_iam_tenancy_ocid == null ? 1 : 0

  input = "fsdr_iam_tenancy_ocid"

  lifecycle {
    precondition {
      condition     = local.fsdr_iam_tenancy_ocid != null
      error_message = "Set fsdr_iam_tenancy_ocid or tenancy_ocid, or point oci_config_file_path/config_file_profile to an OCI config profile with a tenancy entry, when enable_fsdr_iam is true."
    }
  }
}

resource "oci_identity_dynamic_group" "fsdr_resource_principals" {
  count    = var.enable_fsdr_iam && local.fsdr_iam_tenancy_ocid != null ? 1 : 0
  provider = oci.home

  compartment_id = local.fsdr_iam_tenancy_ocid
  description    = "Full Stack DR resource principals for resources in ${var.compartment_ocid}."
  matching_rule  = local.fsdr_dynamic_group_rules
  name           = local.fsdr_dynamic_group_name
}

resource "oci_identity_policy" "fsdr_resource_principal" {
  count    = var.enable_fsdr_iam && local.fsdr_iam_tenancy_ocid != null ? 1 : 0
  provider = oci.home

  compartment_id = local.fsdr_iam_tenancy_ocid
  description    = local.fsdr_policy_description
  name           = local.fsdr_policy_name
  statements = [
    for permission in local.fsdr_policy_permissions :
    "Allow dynamic-group ${oci_identity_dynamic_group.fsdr_resource_principals[0].name} to ${permission}"
  ]
}
