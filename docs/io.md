## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_hub_labels"></a> [hub\_labels](#module\_hub\_labels) | terraform-az-modules/tags/azurerm | 1.0.2 |
| <a name="module_labels"></a> [labels](#module\_labels) | terraform-az-modules/tags/azurerm | 1.0.2 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_express_route_gateway.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/express_route_gateway) | resource |
| [azurerm_monitor_diagnostic_setting.express_route_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_monitor_diagnostic_setting.vpn_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_virtual_hub.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub) | resource |
| [azurerm_virtual_hub_connection.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_connection) | resource |
| [azurerm_virtual_hub_route_table_route.static](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_route_table_route) | resource |
| [azurerm_virtual_wan.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_wan) | resource |
| [azurerm_vpn_gateway.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_gateway) | resource |
| [azurerm_vpn_gateway_connection.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_gateway_connection) | resource |
| [azurerm_vpn_site.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_site) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allow_branch_to_branch_traffic"></a> [allow\_branch\_to\_branch\_traffic](#input\_allow\_branch\_to\_branch\_traffic) | Whether branch to branch traffic is allowed through the Virtual WAN. | `bool` | `true` | no |
| <a name="input_custom_name"></a> [custom\_name](#input\_custom\_name) | Optional custom name to override the base name in tags. | `string` | `null` | no |
| <a name="input_deployment_mode"></a> [deployment\_mode](#input\_deployment\_mode) | Deployment mode identifier (e.g., blue/green, canary). | `string` | `"terraform"` | no |
| <a name="input_diagnostic_setting_enable"></a> [diagnostic\_setting\_enable](#input\_diagnostic\_setting\_enable) | Whether to send gateway logs and metrics to Log Analytics. Must be a literal boolean. | `bool` | `false` | no |
| <a name="input_enable"></a> [enable](#input\_enable) | Enable or disable creation of all resources in this module. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g., dev, stage, prod). | `string` | `null` | no |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Additional tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_hubs"></a> [hubs](#input\_hubs) | Virtual hubs keyed by a short name (for example the region). The gateway toggles must be literal booleans, they decide which resources exist. | <pre>map(object({<br/>    location                          = string<br/>    address_prefix                    = string<br/>    hub_routing_preference            = optional(string, "ExpressRoute")<br/>    vpn_gateway_enabled               = optional(bool, false)<br/>    vpn_gateway_scale_unit            = optional(number, 1)<br/>    express_route_gateway_enabled     = optional(bool, false)<br/>    express_route_gateway_scale_units = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | Order of labels to be used in naming/tagging. | `list(any)` | <pre>[<br/>  "name",<br/>  "environment",<br/>  "location"<br/>]</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region of the Virtual WAN resource itself. Hubs carry their own location. | `string` | `null` | no |
| <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id) | Log Analytics workspace ID for the gateway diagnostic settings. | `string` | `null` | no |
| <a name="input_managedby"></a> [managedby](#input\_managedby) | Tag to indicate the tool or team managing the resources. | `string` | `"terraform"` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for resources. | `string` | `null` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | Repository URL or identifier for traceability. | `string` | `"https://github.com/terraform-az-modules/terraform-azurerm-virtual-wan.git"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group where resources will be deployed. | `string` | `null` | no |
| <a name="input_resource_position_prefix"></a> [resource\_position\_prefix](#input\_resource\_position\_prefix) | If true, the resource type is a prefix of the resource name (vwan-<name>), otherwise a suffix (<name>-vwan). | `bool` | `true` | no |
| <a name="input_virtual_wan_type"></a> [virtual\_wan\_type](#input\_virtual\_wan\_type) | Type of the Virtual WAN and SKU of its hubs: Basic or Standard. | `string` | `"Standard"` | no |
| <a name="input_vnet_connections"></a> [vnet\_connections](#input\_vnet\_connections) | Virtual networks connected to a hub, keyed by connection name. `static_routes` send prefixes that sit behind a network virtual appliance in that network to its IP. With `advertise_static_routes` the same prefixes are added to the hub default route table (next hop the connection), so branches and other hubs learn them. | <pre>map(object({<br/>    hub                       = string<br/>    remote_virtual_network_id = string<br/>    internet_security_enabled = optional(bool, false)<br/>    propagate_static_routes   = optional(bool, true)<br/>    advertise_static_routes   = optional(bool, true)<br/>    static_routes = optional(list(object({<br/>      name                = string<br/>      address_prefixes    = list(string)<br/>      next_hop_ip_address = string<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_vpn_shared_keys"></a> [vpn\_shared\_keys](#input\_vpn\_shared\_keys) | Pre-shared keys keyed by VPN site name, used by every link of that site. A site without an entry gets a key generated by Azure. | `map(string)` | `{}` | no |
| <a name="input_vpn_sites"></a> [vpn\_sites](#input\_vpn\_sites) | VPN sites keyed by site name. `hub` is a key of `hubs` whose VPN gateway is enabled. A link with a `bgp` block uses BGP, otherwise list the site ranges in `address_cidrs`. | <pre>map(object({<br/>    hub           = string<br/>    address_cidrs = optional(list(string), [])<br/>    device_vendor = optional(string)<br/>    device_model  = optional(string)<br/>    links = list(object({<br/>      name          = string<br/>      ip_address    = optional(string)<br/>      fqdn          = optional(string)<br/>      provider_name = optional(string)<br/>      speed_in_mbps = optional(number, 10)<br/>      protocol      = optional(string, "IKEv2")<br/>      bgp = optional(object({<br/>        asn             = number<br/>        peering_address = string<br/>      }))<br/>      ipsec_policy = optional(object({<br/>        dh_group                 = string<br/>        ike_encryption_algorithm = string<br/>        ike_integrity_algorithm  = string<br/>        encryption_algorithm     = string<br/>        integrity_algorithm      = string<br/>        pfs_group                = string<br/>        sa_data_size_kb          = number<br/>        sa_lifetime_sec          = number<br/>      }))<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_express_route_gateway_ids"></a> [express\_route\_gateway\_ids](#output\_express\_route\_gateway\_ids) | Map of hub keys to ExpressRoute gateway IDs. |
| <a name="output_tags"></a> [tags](#output\_tags) | The tags applied to the Virtual WAN. |
| <a name="output_virtual_hub_default_route_table_ids"></a> [virtual\_hub\_default\_route\_table\_ids](#output\_virtual\_hub\_default\_route\_table\_ids) | Map of hub keys to the ID of the hub default route table. |
| <a name="output_virtual_hub_ids"></a> [virtual\_hub\_ids](#output\_virtual\_hub\_ids) | Map of hub keys to virtual hub IDs. |
| <a name="output_virtual_wan_id"></a> [virtual\_wan\_id](#output\_virtual\_wan\_id) | The ID of the Virtual WAN. |
| <a name="output_vnet_connection_ids"></a> [vnet\_connection\_ids](#output\_vnet\_connection\_ids) | Map of connection names to hub virtual network connection IDs. |
| <a name="output_vpn_gateway_bgp_settings"></a> [vpn\_gateway\_bgp\_settings](#output\_vpn\_gateway\_bgp\_settings) | Map of hub keys to the VPN gateway BGP settings (ASN, peering and tunnel addresses of both instances), needed to configure the site devices. |
| <a name="output_vpn_gateway_ids"></a> [vpn\_gateway\_ids](#output\_vpn\_gateway\_ids) | Map of hub keys to VPN gateway IDs. |
| <a name="output_vpn_site_ids"></a> [vpn\_site\_ids](#output\_vpn\_site\_ids) | Map of VPN site names to VPN site IDs. |
