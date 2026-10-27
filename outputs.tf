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

output "palo_alto_cloud_ngfw_ids" {
  value = merge(
    { for k, fw in azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack.cloud_ngfw : k => fw.id },
    { for k, fw in azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama.cloud_ngfw : k => fw.id },
    { for k, fw in azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.cloud_ngfw : k => fw.id },
  )
  description = "Map of hub keys to Palo Alto Cloud NGFW firewall IDs across supported management modes."
}

output "palo_alto_cloud_ngfw_management_modes" {
  value       = { for k, config in local.palo_alto_cloud_ngfw_hubs : k => config.management_mode }
  description = "Map of hub keys to Palo Alto Cloud NGFW management modes."
}

output "palo_alto_virtual_network_appliance_ids" {
  value       = { for k, nva in azurerm_palo_alto_virtual_network_appliance.cloud_ngfw : k => nva.id }
  description = "Map of hub keys to Palo Alto virtual network appliance IDs, used as Routing Intent next hops."
}

output "palo_alto_local_rulestack_ids" {
  value       = { for k, stack in azurerm_palo_alto_local_rulestack.cloud_ngfw : k => stack.id }
  description = "Map of hub keys to Palo Alto local rulestack IDs."
}

output "palo_alto_cloud_ngfw_public_ip_ids" {
  value       = { for k, pip in azurerm_public_ip.palo_alto_cloud_ngfw : k => pip.id }
  description = "Map of hub keys to the Palo Alto Cloud NGFW ingress public IP IDs."
}

output "palo_alto_cloud_ngfw_routing_intent_ids" {
  value       = { for k, intent in azurerm_virtual_hub_routing_intent.palo_alto_cloud_ngfw : k => intent.id }
  description = "Map of hub keys to Palo Alto Cloud NGFW Virtual Hub Routing Intent IDs."
}

output "palo_alto_local_rulestack_prefix_list_ids" {
  value       = { for k, list in azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw : k => list.id }
  description = "Map of hub and prefix-list keys to Palo Alto local rulestack prefix list IDs."
}

output "palo_alto_local_rulestack_fqdn_list_ids" {
  value       = { for k, list in azurerm_palo_alto_local_rulestack_fqdn_list.cloud_ngfw : k => list.id }
  description = "Map of hub and FQDN-list keys to Palo Alto local rulestack FQDN list IDs."
}

output "palo_alto_local_rulestack_rule_ids" {
  value       = { for k, rule in azurerm_palo_alto_local_rulestack_rule.cloud_ngfw : k => rule.id }
  description = "Map of hub and rule keys to Palo Alto local rulestack rule IDs."
}

output "palo_alto_local_rulestack_certificate_ids" {
  value       = { for k, certificate in azurerm_palo_alto_local_rulestack_certificate.cloud_ngfw : k => certificate.id }
  description = "Map of hub and certificate keys to Palo Alto local rulestack certificate IDs."
}

output "palo_alto_outbound_trust_certificate_association_ids" {
  value       = { for k, association in azurerm_palo_alto_local_rulestack_outbound_trust_certificate_association.cloud_ngfw : k => association.id }
  description = "Map of hub keys to outbound trust certificate association IDs."
}

output "palo_alto_outbound_untrust_certificate_association_ids" {
  value       = { for k, association in azurerm_palo_alto_local_rulestack_outbound_untrust_certificate_association.cloud_ngfw : k => association.id }
  description = "Map of hub keys to outbound untrust certificate association IDs."
}

output "tags" {
  value       = module.labels.tags
  description = "The tags applied to the Virtual WAN."
}
