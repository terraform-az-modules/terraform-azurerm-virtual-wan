##-----------------------------------------------------------------------------
# Standard Tagging Module – Applies standard tags to all resources for traceability
##-----------------------------------------------------------------------------
module "labels" {
  source          = "terraform-az-modules/tags/azurerm"
  version         = "1.0.2"
  name            = var.custom_name == null ? var.name : var.custom_name
  location        = var.location
  environment     = var.environment
  managedby       = var.managedby
  label_order     = var.label_order
  repository      = var.repository
  deployment_mode = var.deployment_mode
  extra_tags      = var.extra_tags
}

# One label set per hub, so regional resources carry their own region short name.
module "hub_labels" {
  source          = "terraform-az-modules/tags/azurerm"
  version         = "1.0.2"
  for_each        = local.hubs
  name            = var.custom_name == null ? var.name : var.custom_name
  location        = each.value.location
  environment     = var.environment
  managedby       = var.managedby
  label_order     = var.label_order
  repository      = var.repository
  deployment_mode = var.deployment_mode
  extra_tags      = var.extra_tags
}

##-----------------------------------------------------------------------------
# Virtual WAN
##-----------------------------------------------------------------------------
resource "azurerm_virtual_wan" "main" {
  count                          = var.enable ? 1 : 0
  name                           = var.resource_position_prefix ? format("vwan-%s", local.name) : format("%s-vwan", local.name)
  resource_group_name            = var.resource_group_name
  location                       = var.location
  type                           = var.virtual_wan_type
  allow_branch_to_branch_traffic = var.allow_branch_to_branch_traffic
  tags                           = module.labels.tags
}

##-----------------------------------------------------------------------------
# Virtual Hubs
##-----------------------------------------------------------------------------
resource "azurerm_virtual_hub" "main" {
  for_each               = local.hubs
  name                   = var.resource_position_prefix ? format("vhub-%s", module.hub_labels[each.key].id) : format("%s-vhub", module.hub_labels[each.key].id)
  resource_group_name    = var.resource_group_name
  location               = each.value.location
  virtual_wan_id         = azurerm_virtual_wan.main[0].id
  address_prefix         = each.value.address_prefix
  sku                    = var.virtual_wan_type
  hub_routing_preference = each.value.hub_routing_preference
  # Azure requires the SaaS preview feature tag before creating the Palo Alto hub appliance.
  tags = merge(
    module.hub_labels[each.key].tags,
    contains(keys(local.palo_alto_cloud_ngfw_hubs), each.key) ? { hubSaaSPreview = "true" } : {}
  )
}

##-----------------------------------------------------------------------------
# Site to Site VPN Gateways (two active instances per gateway)
##-----------------------------------------------------------------------------
resource "azurerm_vpn_gateway" "main" {
  for_each            = local.vpn_hubs
  name                = var.resource_position_prefix ? format("vpng-%s", module.hub_labels[each.key].id) : format("%s-vpng", module.hub_labels[each.key].id)
  resource_group_name = var.resource_group_name
  location            = each.value.location
  virtual_hub_id      = azurerm_virtual_hub.main[each.key].id
  scale_unit          = each.value.vpn_gateway_scale_unit
  tags                = module.hub_labels[each.key].tags
}

##-----------------------------------------------------------------------------
# ExpressRoute Gateways
##-----------------------------------------------------------------------------
resource "azurerm_express_route_gateway" "main" {
  for_each            = local.express_route_hubs
  name                = var.resource_position_prefix ? format("ergw-%s", module.hub_labels[each.key].id) : format("%s-ergw", module.hub_labels[each.key].id)
  resource_group_name = var.resource_group_name
  location            = each.value.location
  virtual_hub_id      = azurerm_virtual_hub.main[each.key].id
  scale_units         = each.value.express_route_gateway_scale_units
  tags                = module.hub_labels[each.key].tags
}

##-----------------------------------------------------------------------------
# VPN Sites and their connections to the hub VPN gateway
##-----------------------------------------------------------------------------
resource "azurerm_vpn_site" "main" {
  for_each            = local.vpn_sites
  name                = var.resource_position_prefix ? format("vst-%s-%s", each.key, module.hub_labels[each.value.hub].id) : format("%s-%s-vst", module.hub_labels[each.value.hub].id, each.key)
  resource_group_name = var.resource_group_name
  location            = local.hubs[each.value.hub].location
  virtual_wan_id      = azurerm_virtual_wan.main[0].id
  address_cidrs       = each.value.address_cidrs
  device_vendor       = each.value.device_vendor
  device_model        = each.value.device_model
  tags                = module.hub_labels[each.value.hub].tags

  dynamic "link" {
    for_each = each.value.links
    content {
      name          = link.value.name
      ip_address    = link.value.ip_address
      fqdn          = link.value.fqdn
      provider_name = link.value.provider_name
      speed_in_mbps = link.value.speed_in_mbps

      dynamic "bgp" {
        for_each = link.value.bgp == null ? [] : [link.value.bgp]
        content {
          asn             = bgp.value.asn
          peering_address = bgp.value.peering_address
        }
      }
    }
  }
}

resource "azurerm_vpn_gateway_connection" "main" {
  for_each           = local.vpn_sites
  name               = format("%s-connection", each.key)
  vpn_gateway_id     = azurerm_vpn_gateway.main[each.value.hub].id
  remote_vpn_site_id = azurerm_vpn_site.main[each.key].id

  dynamic "vpn_link" {
    for_each = each.value.links
    content {
      name             = vpn_link.value.name
      vpn_site_link_id = azurerm_vpn_site.main[each.key].link[vpn_link.key].id
      shared_key       = lookup(var.vpn_shared_keys, each.key, null)
      bgp_enabled      = vpn_link.value.bgp != null
      protocol         = vpn_link.value.protocol
      bandwidth_mbps   = vpn_link.value.speed_in_mbps

      dynamic "ipsec_policy" {
        for_each = vpn_link.value.ipsec_policy == null ? [] : [vpn_link.value.ipsec_policy]
        content {
          dh_group                 = ipsec_policy.value.dh_group
          ike_encryption_algorithm = ipsec_policy.value.ike_encryption_algorithm
          ike_integrity_algorithm  = ipsec_policy.value.ike_integrity_algorithm
          encryption_algorithm     = ipsec_policy.value.encryption_algorithm
          integrity_algorithm      = ipsec_policy.value.integrity_algorithm
          pfs_group                = ipsec_policy.value.pfs_group
          sa_data_size_kb          = ipsec_policy.value.sa_data_size_kb
          sa_lifetime_sec          = ipsec_policy.value.sa_lifetime_sec
        }
      }
    }
  }
}

##-----------------------------------------------------------------------------
# Hub Virtual Network Connections, with optional static routes to an NVA
##-----------------------------------------------------------------------------
resource "azurerm_virtual_hub_connection" "main" {
  for_each                  = local.vnet_connections
  name                      = format("%s-connection", each.key)
  virtual_hub_id            = azurerm_virtual_hub.main[each.value.hub].id
  remote_virtual_network_id = each.value.remote_virtual_network_id
  internet_security_enabled = each.value.internet_security_enabled

  # Always managed, so removing static_routes also removes them in Azure. Without
  # static routes the block names the hub default route table (an empty block is
  # rejected); that is also the association Routing Intent uses.
  routing {
    associated_route_table_id                   = length(each.value.static_routes) > 0 ? null : azurerm_virtual_hub.main[each.value.hub].default_route_table_id
    static_vnet_propagate_static_routes_enabled = each.value.propagate_static_routes

    dynamic "static_vnet_route" {
      for_each = each.value.static_routes
      content {
        name                = static_vnet_route.value.name
        address_prefixes    = static_vnet_route.value.address_prefixes
        next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
      }
    }
  }
}

# Static route in the hub default route table, next hop the connection. Without
# it the prefixes behind the NVA are not advertised to branches or other hubs.
resource "azurerm_virtual_hub_route_table_route" "static" {
  for_each          = local.advertised_connections
  route_table_id    = azurerm_virtual_hub.main[each.value.hub].default_route_table_id
  name              = format("%s-static", each.key)
  destinations_type = "CIDR"
  destinations      = distinct(flatten([for r in each.value.static_routes : r.address_prefixes]))
  next_hop_type     = "ResourceId"
  next_hop          = azurerm_virtual_hub_connection.main[each.key].id
}

##-----------------------------------------------------------------------------
# Diagnostic Settings for the gateways
##-----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vpn_gateway" {
  for_each                   = var.diagnostic_setting_enable ? local.vpn_hubs : {}
  name                       = format("%s-diag-log", azurerm_vpn_gateway.main[each.key].name)
  target_resource_id         = azurerm_vpn_gateway.main[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "express_route_gateway" {
  for_each                   = var.diagnostic_setting_enable ? local.express_route_hubs : {}
  name                       = format("%s-diag-log", azurerm_express_route_gateway.main[each.key].name)
  target_resource_id         = azurerm_express_route_gateway.main[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "AllMetrics"
  }
}
