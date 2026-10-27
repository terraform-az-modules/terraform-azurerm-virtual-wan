##-----------------------------------------------------------------------------
## Locals
##-----------------------------------------------------------------------------
locals {
  name = var.custom_name != null ? var.custom_name : module.labels.id

  hubs             = var.enable ? var.hubs : {}
  vpn_sites        = var.enable ? var.vpn_sites : {}
  vnet_connections = var.enable ? var.vnet_connections : {}
  palo_alto_cloud_ngfw_hubs = var.enable ? {
    for k, v in var.palo_alto_cloud_ngfw : k => merge(local.hubs[k], v)
    if contains(keys(local.hubs), k)
  } : {}
  palo_alto_local_rulestack_hubs = {
    for k, v in local.palo_alto_cloud_ngfw_hubs : k => v if v.management_mode == "local_rulestack"
  }

  vpn_hubs           = { for k, h in local.hubs : k => h if h.vpn_gateway_enabled }
  express_route_hubs = { for k, h in local.hubs : k => h if h.express_route_gateway_enabled }

  # Connections whose static routes are also written to the hub default route
  # table, so branches and the other hubs learn the prefixes behind the NVA.
  advertised_connections = { for k, c in local.vnet_connections : k => c if c.advertise_static_routes && length(c.static_routes) > 0 }
}
