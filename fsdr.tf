resource "oci_disaster_recovery_dr_protection_group" "primary" {
  count    = var.enable_fsdr ? 1 : 0
  provider = oci.primary

  compartment_id       = var.compartment_ocid
  display_name         = "${var.name_prefix}-${module.primary_oke.region_short_name}-drpg"
  disassociate_trigger = var.fsdr_disassociate_trigger

  log_location {
    bucket    = module.primary_oke.object_storage_buckets.fsdr_logs.name
    namespace = module.primary_oke.object_storage_buckets.fsdr_logs.namespace
  }

  freeform_tags = merge(var.freeform_tags, {
    lab               = var.name_prefix
    region_short_name = module.primary_oke.region_short_name
    purpose           = "fsdr"
  })

  depends_on = [
    oci_identity_policy.fsdr_resource_principal,
    terraform_data.fsdr_iam_tenancy_required,
  ]

  lifecycle {
    # Members are configured in subsequent hands-on lab steps.
    ignore_changes = [members]

    precondition {
      condition     = var.primary_region != var.standby_region
      error_message = "Full Stack DR requires different primary_region and standby_region values for this dual-region lab."
    }
  }
}

resource "oci_disaster_recovery_dr_protection_group" "standby" {
  count    = var.enable_fsdr ? 1 : 0
  provider = oci.standby

  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-${module.standby_oke.region_short_name}-drpg"

  log_location {
    bucket    = module.standby_oke.object_storage_buckets.fsdr_logs.name
    namespace = module.standby_oke.object_storage_buckets.fsdr_logs.namespace
  }

  # A single association assigns PRIMARY to the existing peer as well.
  association {
    role        = "STANDBY"
    peer_id     = oci_disaster_recovery_dr_protection_group.primary[0].id
    peer_region = var.primary_region
  }

  freeform_tags = merge(var.freeform_tags, {
    lab               = var.name_prefix
    region_short_name = module.standby_oke.region_short_name
    purpose           = "fsdr"
  })

  lifecycle {
    ignore_changes = [members]
  }
}

# Read both groups after pairing so outputs reflect their final roles and peers.
data "oci_disaster_recovery_dr_protection_group" "primary" {
  count    = var.enable_fsdr ? 1 : 0
  provider = oci.primary

  dr_protection_group_id = oci_disaster_recovery_dr_protection_group.primary[0].id

  depends_on = [
    oci_disaster_recovery_dr_protection_group.primary,
    oci_disaster_recovery_dr_protection_group.standby,
  ]
}

data "oci_disaster_recovery_dr_protection_group" "standby" {
  count    = var.enable_fsdr ? 1 : 0
  provider = oci.standby

  dr_protection_group_id = oci_disaster_recovery_dr_protection_group.standby[0].id

  depends_on = [
    oci_disaster_recovery_dr_protection_group.primary,
    oci_disaster_recovery_dr_protection_group.standby,
  ]
}
