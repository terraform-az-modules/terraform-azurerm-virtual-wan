##-----------------------------------------------------------------------------
## Outputs
##-----------------------------------------------------------------------------
output "virtual_wan_id" {
  value       = module.virtual_wan.virtual_wan_id
  description = "The ID of the Virtual WAN."
}

output "virtual_hub_ids" {
  value       = module.virtual_wan.virtual_hub_ids
  description = "Map of hub keys to virtual hub IDs."
}
