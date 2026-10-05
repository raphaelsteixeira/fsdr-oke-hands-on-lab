mock_provider "oci" {
  alias = "primary"

  mock_resource "oci_disaster_recovery_dr_protection_group" {
    defaults = {
      id   = "ocid1.drprotectiongroup.oc1.eu-frankfurt-1.mock-primary"
      role = "UNCONFIGURED"
    }
  }

  mock_data "oci_disaster_recovery_dr_protection_group" {
    defaults = {
      role        = "PRIMARY"
      peer_id     = "ocid1.drprotectiongroup.oc1.eu-madrid-1.mock-standby"
      peer_region = "eu-madrid-1"
    }
  }
}

mock_provider "oci" {
  alias = "standby"

  mock_resource "oci_disaster_recovery_dr_protection_group" {
    defaults = {
      id   = "ocid1.drprotectiongroup.oc1.eu-madrid-1.mock-standby"
      role = "STANDBY"
    }
  }

  mock_data "oci_disaster_recovery_dr_protection_group" {
    defaults = {
      role        = "STANDBY"
      peer_id     = "ocid1.drprotectiongroup.oc1.eu-frankfurt-1.mock-primary"
      peer_region = "eu-frankfurt-1"
    }
  }
}

mock_provider "oci" {
  alias = "home"
}

override_module {
  target = module.primary_oke
  outputs = {
    region_short_name = "fra"
    cluster_id        = "mock-cluster-fra"
    cluster_name      = "oke-dr-lab-fra-oke"
    node_pool_id      = "mock-node-pool-fra"
    vcn_id            = "mock-vcn-fra"
    subnet_ids        = {}
    nsg_ids           = {}
    file_storage      = null
    object_storage_buckets = {
      fsdr_logs = {
        id        = "mock-log-bucket-fra"
        name      = "oke-dr-lab-fra-fsdr-logs"
        namespace = "mock-namespace"
      }
    }
  }
}

override_module {
  target = module.standby_oke
  outputs = {
    region_short_name = "mad"
    cluster_id        = "mock-cluster-mad"
    cluster_name      = "oke-dr-lab-mad-oke"
    node_pool_id      = "mock-node-pool-mad"
    vcn_id            = "mock-vcn-mad"
    subnet_ids        = {}
    nsg_ids           = {}
    file_storage      = null
    object_storage_buckets = {
      fsdr_logs = {
        id        = "mock-log-bucket-mad"
        name      = "oke-dr-lab-mad-fsdr-logs"
        namespace = "mock-namespace"
      }
    }
  }
}

variables {
  compartment_ocid      = "ocid1.compartment.oc1..mock-compartment"
  primary_region        = "eu-frankfurt-1"
  standby_region        = "eu-madrid-1"
  fsdr_iam_tenancy_ocid = "ocid1.tenancy.oc1..mock-tenancy"
  oci_config_file_path  = ""
  tenancy_ocid          = null
}

run "create_associated_drpgs" {
  command = apply

  providers = {
    oci.primary = oci.primary
    oci.standby = oci.standby
    oci.home    = oci.home
  }

  assert {
    condition = (
      oci_disaster_recovery_dr_protection_group.primary[0].display_name == "oke-dr-lab-fra-drpg" &&
      oci_disaster_recovery_dr_protection_group.standby[0].display_name == "oke-dr-lab-mad-drpg"
    )
    error_message = "DRPG names must use the region short labels."
  }

  assert {
    condition = (
      oci_disaster_recovery_dr_protection_group.primary[0].log_location[0].bucket == "oke-dr-lab-fra-fsdr-logs" &&
      oci_disaster_recovery_dr_protection_group.standby[0].log_location[0].bucket == "oke-dr-lab-mad-fsdr-logs"
    )
    error_message = "Each DRPG must reuse its own region's FSDR log bucket."
  }

  assert {
    condition = (
      oci_disaster_recovery_dr_protection_group.standby[0].association[0].role == "STANDBY" &&
      oci_disaster_recovery_dr_protection_group.standby[0].association[0].peer_id == oci_disaster_recovery_dr_protection_group.primary[0].id &&
      oci_disaster_recovery_dr_protection_group.standby[0].association[0].peer_region == var.primary_region
    )
    error_message = "The standby DRPG must associate to the primary DRPG in the correct region."
  }

  assert {
    condition = (
      output.fsdr.primary.role == "PRIMARY" &&
      output.fsdr.standby.role == "STANDBY" &&
      output.fsdr.primary.peer_id == output.fsdr.standby.id &&
      output.fsdr.standby.peer_id == output.fsdr.primary.id
    )
    error_message = "Outputs must use post-association reads, not the initially unconfigured primary role."
  }
}

run "external_iam_is_supported" {
  command = plan

  providers = {
    oci.primary = oci.primary
    oci.standby = oci.standby
    oci.home    = oci.home
  }

  variables {
    enable_fsdr_iam = false
  }

  assert {
    condition = (
      length(oci_identity_policy.fsdr_resource_principal) == 0 &&
      length(oci_disaster_recovery_dr_protection_group.primary) == 1 &&
      length(oci_disaster_recovery_dr_protection_group.standby) == 1
    )
    error_message = "DRPG creation must also work when IAM is managed separately."
  }
}

run "drpg_creation_can_be_disabled" {
  command = plan

  providers = {
    oci.primary = oci.primary
    oci.standby = oci.standby
    oci.home    = oci.home
  }

  variables {
    enable_fsdr     = false
    enable_fsdr_iam = false
  }

  assert {
    condition = (
      length(oci_disaster_recovery_dr_protection_group.primary) == 0 &&
      length(oci_disaster_recovery_dr_protection_group.standby) == 0 &&
      output.fsdr == null
    )
    error_message = "Disabling Full Stack DR must omit both groups and their output."
  }
}

run "same_region_pair_is_rejected" {
  command = plan

  providers = {
    oci.primary = oci.primary
    oci.standby = oci.standby
    oci.home    = oci.home
  }

  variables {
    standby_region = "eu-frankfurt-1"
  }

  expect_failures = [oci_disaster_recovery_dr_protection_group.primary[0]]
}

run "fractional_disassociation_trigger_is_rejected" {
  command = plan

  providers = {
    oci.primary = oci.primary
    oci.standby = oci.standby
    oci.home    = oci.home
  }

  variables {
    fsdr_disassociate_trigger = 0.5
  }

  expect_failures = [var.fsdr_disassociate_trigger]
}
