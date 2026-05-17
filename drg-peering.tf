resource "oci_core_remote_peering_connection" "standby" {
  provider = oci.standby

  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-${local.standby_region_short_name}-to-${local.primary_region_short_name}-rpc"
  drg_id         = module.standby_oke.drg.id
  freeform_tags = merge(var.freeform_tags, {
    lab          = var.name_prefix
    peering_role = "acceptor"
  })
}

resource "oci_core_remote_peering_connection" "primary" {
  provider = oci.primary

  compartment_id   = var.compartment_ocid
  display_name     = "${var.name_prefix}-${local.primary_region_short_name}-to-${local.standby_region_short_name}-rpc"
  drg_id           = module.primary_oke.drg.id
  peer_id          = oci_core_remote_peering_connection.standby.id
  peer_region_name = var.standby_region
  freeform_tags = merge(var.freeform_tags, {
    lab          = var.name_prefix
    peering_role = "requestor"
  })
}
