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
# Palo Alto Cloud NGFW
##-----------------------------------------------------------------------------
variable "palo_alto_cloud_ngfw" {
  type = map(object({
    management_mode = optional(string, "local_rulestack")
    rulestack = optional(object({
      description           = optional(string)
      anti_spyware_profile  = optional(string)
      anti_virus_profile    = optional(string)
      file_blocking_profile = optional(string)
      url_filtering_profile = optional(string)
      vulnerability_profile = optional(string)
      dns_subscription      = optional(string)
    }))
    prefix_lists = optional(map(object({
      prefixes      = list(string)
      description   = optional(string)
      audit_comment = optional(string)
    })), {})
    fqdn_lists = optional(map(object({
      fqdns         = list(string)
      description   = optional(string)
      audit_comment = optional(string)
    })), {})
    certificates = optional(map(object({
      self_signed              = optional(bool)
      key_vault_certificate_id = optional(string)
      description              = optional(string)
      audit_comment            = optional(string)
    })), {})
    outbound_trust_certificate_name   = optional(string)
    outbound_untrust_certificate_name = optional(string)
    panorama_base64_config            = optional(string)
    strata_cloud_manager_tenant_name  = optional(string)
    identity = optional(object({
      type         = string
      identity_ids = list(string)
    }))
    marketplace_offer_id = optional(string)
    plan_id              = optional(string)
    rules = optional(map(object({
      priority     = number
      action       = string
      applications = list(string)
      source = object({
        cidrs                           = optional(list(string))
        countries                       = optional(list(string))
        feeds                           = optional(list(string))
        local_rulestack_prefix_list_ids = optional(list(string))
      })
      destination = object({
        cidrs                           = optional(list(string))
        countries                       = optional(list(string))
        feeds                           = optional(list(string))
        local_rulestack_fqdn_list_ids   = optional(list(string))
        local_rulestack_prefix_list_ids = optional(list(string))
      })
      protocol                    = optional(string)
      protocol_ports              = optional(list(string))
      description                 = optional(string)
      enabled                     = optional(bool, true)
      logging_enabled             = optional(bool, true)
      negate_source               = optional(bool, false)
      negate_destination          = optional(bool, false)
      audit_comment               = optional(string)
      decryption_rule_type        = optional(string, "None")
      inspection_certificate_id   = optional(string)
      inspection_certificate_name = optional(string)
      category = optional(object({
        custom_urls = optional(list(string), [])
        feeds       = optional(list(string), [])
      }))
    })), {})
    additional_public_ip_address_ids = optional(list(string), [])
    egress_nat_ip_address_ids        = optional(list(string), [])
    trusted_address_ranges           = optional(list(string), [])
    dns_settings = optional(object({
      dns_servers   = optional(list(string))
      use_azure_dns = optional(bool, false)
    }))
    destination_nat = optional(map(object({
      protocol                  = string
      frontend_port             = number
      public_ip_address_id      = optional(string)
      backend_port              = number
      backend_public_ip_address = string
    })), {})
    routing_policies = optional(list(object({
      name         = string
      destinations = list(string)
    })), [])
    log_settings = optional(object({
      log_type = optional(string)
    }))
  }))
  default     = {}
  description = "Optional Azure managed Palo Alto Cloud NGFW per hub. Configure a local rulestack, its rules, and Routing Intent policies. The map key must reference a hub in hubs. `destination_nat.public_ip_address_id` defaults to the module's public IP; any other frontend must be listed in `additional_public_ip_address_ids`. `log_settings` sends firewall logs to `log_analytics_workspace_id` (read with the default azurerm provider) through the saveLogProfile action."

  validation {
    condition = alltrue([
      for hub, config in var.palo_alto_cloud_ngfw :
      contains(keys(var.hubs), hub) && contains(["local_rulestack", "panorama", "strata_cloud_manager"], config.management_mode) &&
      (config.management_mode != "local_rulestack" || config.rulestack != null) &&
      (config.management_mode == "local_rulestack" || config.rulestack == null) &&
      (config.management_mode != "panorama" || config.panorama_base64_config != null) &&
      (config.management_mode != "strata_cloud_manager" || config.strata_cloud_manager_tenant_name != null) &&
      (config.identity == null || config.management_mode == "strata_cloud_manager") &&
      (config.management_mode == "local_rulestack" || (length(config.rules) == 0 && length(config.prefix_lists) == 0 && length(config.fqdn_lists) == 0 && length(config.certificates) == 0 && config.outbound_trust_certificate_name == null && config.outbound_untrust_certificate_name == null))
    ])
    error_message = "Each palo_alto_cloud_ngfw entry must reference a hub and provide the configuration required by its management_mode."
  }

  validation {
    condition = alltrue(flatten([
      for _, config in var.palo_alto_cloud_ngfw : [
        for _, certificate in config.certificates : (certificate.self_signed != null) != (certificate.key_vault_certificate_id != null)
      ]
    ]))
    error_message = "Each Palo Alto certificate must set exactly one of self_signed or key_vault_certificate_id."
  }

  validation {
    condition = alltrue([
      for _, config in var.palo_alto_cloud_ngfw :
      (config.outbound_trust_certificate_name == null || contains(keys(config.certificates), config.outbound_trust_certificate_name)) &&
      (config.outbound_untrust_certificate_name == null || contains(keys(config.certificates), config.outbound_untrust_certificate_name))
    ])
    error_message = "Outbound trust and untrust certificate names must refer to certificates in the same hub configuration."
  }

  validation {
    condition = alltrue(flatten([
      for _, config in var.palo_alto_cloud_ngfw : [
        for _, rule in config.rules :
        (rule.inspection_certificate_name == null || contains(keys(config.certificates), rule.inspection_certificate_name)) &&
        !(rule.inspection_certificate_name != null && rule.inspection_certificate_id != null)
      ]
    ]))
    error_message = "Inspection certificate names must reference a certificate in the same hub and cannot be combined with inspection_certificate_id."
  }

  validation {
    condition     = length(var.palo_alto_cloud_ngfw) == 0 || var.virtual_wan_type == "Standard"
    error_message = "Palo Alto Cloud NGFW requires virtual_wan_type = Standard."
  }

  validation {
    condition = alltrue([
      for _, config in var.palo_alto_cloud_ngfw :
      config.dns_settings == null ||
      (config.dns_settings.use_azure_dns ? length(coalesce(config.dns_settings.dns_servers, [])) == 0 : length(coalesce(config.dns_settings.dns_servers, [])) > 0)
    ])
    error_message = "When Palo Alto DNS settings are configured, set use_azure_dns=true or provide one or more dns_servers, but not both."
  }

  validation {
    condition = alltrue(flatten([
      for _, config in var.palo_alto_cloud_ngfw : [
        for _, rule in config.rules : (rule.protocol != null) != (rule.protocol_ports != null)
      ]
    ]))
    error_message = "Each Palo Alto rule must set exactly one of protocol or protocol_ports."
  }

  validation {
    condition = alltrue(flatten([
      for _, config in var.palo_alto_cloud_ngfw : [
        for policy in config.routing_policies : contains(["InternetTrafficPolicy", "PrivateTrafficPolicy"], policy.name)
      ]
    ]))
    error_message = "Palo Alto Routing Intent policy names must be InternetTrafficPolicy or PrivateTrafficPolicy."
  }

  validation {
    condition = alltrue(flatten([
      for _, config in var.palo_alto_cloud_ngfw : [
        length(distinct([for policy in config.routing_policies : policy.name])) == length(config.routing_policies),
        [for policy in config.routing_policies : policy.destinations == tolist(policy.name == "InternetTrafficPolicy" ? ["Internet"] : ["PrivateTraffic"])],
      ]
    ]))
    error_message = "Use each Routing Intent policy once per hub: InternetTrafficPolicy with destinations [\"Internet\"], PrivateTrafficPolicy with [\"PrivateTraffic\"]."
  }

  validation {
    condition = alltrue(flatten([
      for _, config in var.palo_alto_cloud_ngfw : [
        for _, nat in config.destination_nat : nat.public_ip_address_id == null || contains(config.additional_public_ip_address_ids, nat.public_ip_address_id)
      ]
    ]))
    error_message = "A destination_nat public_ip_address_id must be omitted (module public IP) or listed in additional_public_ip_address_ids."
  }

  validation {
    condition = alltrue([
      for _, config in var.palo_alto_cloud_ngfw :
      config.log_settings == null || (
        var.log_analytics_workspace_id != null &&
        (config.log_settings.log_type == null || contains(["TRAFFIC", "THREAT", "DECRYPTION", "WILDFIRE", "DLP", "AUDIT"], config.log_settings.log_type))
      )
    ])
    error_message = "log_settings needs log_analytics_workspace_id, and log_type must be one of TRAFFIC, THREAT, DECRYPTION, WILDFIRE, DLP or AUDIT."
  }
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
  description = "Log Analytics workspace ID for the gateway diagnostic settings and the Palo Alto Cloud NGFW log profile."
}
