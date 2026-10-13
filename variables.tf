##-----------------------------------------------------------------------------
# Global
##-----------------------------------------------------------------------------
variable "enable" {
  type        = bool
  default     = true
  description = "Enable or disable creation of all resources in this module."
}

variable "name" {
  type        = string
  default     = null
  description = "Base name for resources."
}

variable "custom_name" {
  type        = string
  default     = null
  description = "Optional custom name to override the base name in tags."
}

variable "location" {
  type        = string
  default     = null
  description = "Azure region of the Virtual WAN resource itself. Hubs carry their own location."
}

variable "environment" {
  type        = string
  default     = null
  description = "Deployment environment (e.g., dev, stage, prod)."
}

variable "resource_group_name" {
  type        = string
  default     = null
  description = "Name of the resource group where resources will be deployed."
}

variable "managedby" {
  type        = string
  default     = "terraform"
  description = "Tag to indicate the tool or team managing the resources."
}

variable "repository" {
  type        = string
  default     = "https://github.com/terraform-az-modules/terraform-azurerm-virtual-wan.git"
  description = "Repository URL or identifier for traceability."
}

variable "deployment_mode" {
  type        = string
  default     = "terraform"
  description = "Deployment mode identifier (e.g., blue/green, canary)."
}

variable "label_order" {
  type        = list(any)
  default     = ["name", "environment", "location"]
  description = "Order of labels to be used in naming/tagging."
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources."
}

variable "resource_position_prefix" {
  type        = bool
  default     = true
  description = "If true, the resource type is a prefix of the resource name (vwan-<name>), otherwise a suffix (<name>-vwan)."
}

##-----------------------------------------------------------------------------
# Virtual WAN
##-----------------------------------------------------------------------------
variable "virtual_wan_type" {
  type        = string
  default     = "Standard"
  description = "Type of the Virtual WAN and SKU of its hubs: Basic or Standard."

  validation {
    condition     = contains(["Basic", "Standard"], var.virtual_wan_type)
    error_message = "virtual_wan_type must be Basic or Standard."
  }
}

variable "allow_branch_to_branch_traffic" {
  type        = bool
  default     = true
  description = "Whether branch to branch traffic is allowed through the Virtual WAN."
}

##-----------------------------------------------------------------------------
# Hubs and gateways
##-----------------------------------------------------------------------------
variable "hubs" {
  type = map(object({
    location                          = string
    address_prefix                    = string
    hub_routing_preference            = optional(string, "ExpressRoute")
    vpn_gateway_enabled               = optional(bool, false)
    vpn_gateway_scale_unit            = optional(number, 1)
    express_route_gateway_enabled     = optional(bool, false)
    express_route_gateway_scale_units = optional(number, 1)
  }))
  default     = {}
  description = "Virtual hubs keyed by a short name (for example the region). The gateway toggles must be literal booleans, they decide which resources exist."
}

##-----------------------------------------------------------------------------
# VPN sites
##-----------------------------------------------------------------------------
variable "vpn_sites" {
  type = map(object({
    hub           = string
    address_cidrs = optional(list(string), [])
    device_vendor = optional(string)
    device_model  = optional(string)
    links = list(object({
      name          = string
      ip_address    = optional(string)
      fqdn          = optional(string)
      provider_name = optional(string)
      speed_in_mbps = optional(number, 10)
      protocol      = optional(string, "IKEv2")
      bgp = optional(object({
        asn             = number
        peering_address = string
      }))
      ipsec_policy = optional(object({
        dh_group                 = string
        ike_encryption_algorithm = string
        ike_integrity_algorithm  = string
        encryption_algorithm     = string
        integrity_algorithm      = string
        pfs_group                = string
        sa_data_size_kb          = number
        sa_lifetime_sec          = number
      }))
    }))
  }))
  default     = {}
  description = "VPN sites keyed by site name. `hub` is a key of `hubs` whose VPN gateway is enabled. A link with a `bgp` block uses BGP, otherwise list the site ranges in `address_cidrs`."
}

variable "vpn_shared_keys" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Pre-shared keys keyed by VPN site name, used by every link of that site. A site without an entry gets a key generated by Azure."
}

##-----------------------------------------------------------------------------
# Hub virtual network connections
##-----------------------------------------------------------------------------
variable "vnet_connections" {
  type = map(object({
    hub                       = string
    remote_virtual_network_id = string
    internet_security_enabled = optional(bool, false)
    propagate_static_routes   = optional(bool, true)
    advertise_static_routes   = optional(bool, true)
    static_routes = optional(list(object({
      name                = string
      address_prefixes    = list(string)
      next_hop_ip_address = string
    })), [])
  }))
  default     = {}
  description = "Virtual networks connected to a hub, keyed by connection name. `static_routes` send prefixes that sit behind a network virtual appliance in that network to its IP. With `advertise_static_routes` the same prefixes are added to the hub default route table (next hop the connection), so branches and other hubs learn them."
}

##-----------------------------------------------------------------------------
# Diagnostics
##-----------------------------------------------------------------------------
variable "diagnostic_setting_enable" {
  type        = bool
  default     = false
  description = "Whether to send gateway logs and metrics to Log Analytics. Must be a literal boolean."
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "Log Analytics workspace ID for the gateway diagnostic settings."
}
