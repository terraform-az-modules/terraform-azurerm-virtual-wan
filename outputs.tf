##-----------------------------------------------------------------------------
## Outputs
##-----------------------------------------------------------------------------
output "virtual_wan_id" {
  value       = try(azurerm_virtual_wan.main[0].id, null)
  description = "The ID of the Virtual WAN."
}

output "virtual_hub_ids" {
  value       = { for k, h in azurerm_virtual_hub.main : k => h.id }
  description = "Map of hub keys to virtual hub IDs."
}

output "virtual_hub_default_route_table_ids" {
  value       = { for k, h in azurerm_virtual_hub.main : k => h.default_route_table_id }
  description = "Map of hub keys to the ID of the hub default route table."
}

output "vpn_gateway_ids" {
  value       = { for k, g in azurerm_vpn_gateway.main : k => g.id }
  description = "Map of hub keys to VPN gateway IDs."
}

output "vpn_gateway_bgp_settings" {
  value       = { for k, g in azurerm_vpn_gateway.main : k => g.bgp_settings }
  description = "Map of hub keys to the VPN gateway BGP settings (ASN, peering and tunnel addresses of both instances), needed to configure the site devices."
}

output "express_route_gateway_ids" {
  value       = { for k, g in azurerm_express_route_gateway.main : k => g.id }
  description = "Map of hub keys to ExpressRoute gateway IDs."
}

output "vpn_site_ids" {
  value       = { for k, s in azurerm_vpn_site.main : k => s.id }
  description = "Map of VPN site names to VPN site IDs."
}

output "vnet_connection_ids" {
  value       = { for k, c in azurerm_virtual_hub_connection.main : k => c.id }
  description = "Map of connection names to hub virtual network connection IDs."
}

output "tags" {
  value       = module.labels.tags
  description = "The tags applied to the Virtual WAN."
}
