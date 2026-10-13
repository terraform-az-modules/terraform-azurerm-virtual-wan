<!-- BEGIN_TF_DOCS -->

# Terraform Azure Virtual WAN Module

This directory contains an example usage of the **terraform-azurerm-virtual-wan** module. It creates a Virtual WAN with one hub and a site to site VPN gateway, a VPN site with BGP, and a hub virtual network connection with a static route to a network virtual appliance.

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | terraform-az-modules/resource-group/azurerm | 1.0.4 |
| <a name="module_virtual_wan"></a> [virtual\_wan](#module\_virtual\_wan) | ../../ | n/a |
| <a name="module_vnet"></a> [vnet](#module\_vnet) | terraform-az-modules/vnet/azurerm | 1.0.4 |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_virtual_hub_ids"></a> [virtual\_hub\_ids](#output\_virtual\_hub\_ids) | Map of hub keys to virtual hub IDs. |
| <a name="output_virtual_wan_id"></a> [virtual\_wan\_id](#output\_virtual\_wan\_id) | The ID of the Virtual WAN. |

<!-- END_TF_DOCS -->
