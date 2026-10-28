output "virtual_wan_id" {
  value       = module.virtual_wan.virtual_wan_id
  description = "The ID of the Virtual WAN."
}

output "virtual_hub_ids" {
  value       = module.virtual_wan.virtual_hub_ids
  description = "Map of hub keys to Virtual Hub IDs."
}

output "palo_alto_cloud_ngfw_ids" {
  value       = module.virtual_wan.palo_alto_cloud_ngfw_ids
  description = "Map of hub keys to Palo Alto Cloud NGFW firewall IDs."
}

output "palo_alto_cloud_ngfw_management_modes" {
  value       = module.virtual_wan.palo_alto_cloud_ngfw_management_modes
  description = "Map of hub keys to Palo Alto Cloud NGFW management modes."
}

output "palo_alto_virtual_network_appliance_ids" {
  value       = module.virtual_wan.palo_alto_virtual_network_appliance_ids
  description = "Map of hub keys to Palo Alto virtual network appliance IDs."
}

output "palo_alto_local_rulestack_ids" {
  value       = module.virtual_wan.palo_alto_local_rulestack_ids
  description = "Map of hub keys to local rulestack IDs."
}

output "palo_alto_cloud_ngfw_public_ip_ids" {
  value       = module.virtual_wan.palo_alto_cloud_ngfw_public_ip_ids
  description = "Map of hub keys to Cloud NGFW public IP IDs."
}

output "palo_alto_cloud_ngfw_routing_intent_ids" {
  value       = module.virtual_wan.palo_alto_cloud_ngfw_routing_intent_ids
  description = "Map of hub keys to Routing Intent IDs."
}

output "palo_alto_local_rulestack_rule_ids" {
  value       = module.virtual_wan.palo_alto_local_rulestack_rule_ids
  description = "Map of hub and rule keys to local rulestack rule IDs."
}

output "palo_alto_local_rulestack_prefix_list_ids" {
  value       = module.virtual_wan.palo_alto_local_rulestack_prefix_list_ids
  description = "Map of hub and prefix list keys to local rulestack prefix list IDs."
}

output "palo_alto_local_rulestack_fqdn_list_ids" {
  value       = module.virtual_wan.palo_alto_local_rulestack_fqdn_list_ids
  description = "Map of hub and FQDN list keys to local rulestack FQDN list IDs."
}

output "palo_alto_local_rulestack_certificate_ids" {
  value       = module.virtual_wan.palo_alto_local_rulestack_certificate_ids
  description = "Map of hub and certificate keys to local rulestack certificate IDs."
}

output "palo_alto_outbound_trust_certificate_association_ids" {
  value       = module.virtual_wan.palo_alto_outbound_trust_certificate_association_ids
  description = "Map of hub keys to outbound trust certificate association IDs."
}

output "palo_alto_outbound_untrust_certificate_association_ids" {
  value       = module.virtual_wan.palo_alto_outbound_untrust_certificate_association_ids
  description = "Map of hub keys to outbound untrust certificate association IDs."
}
