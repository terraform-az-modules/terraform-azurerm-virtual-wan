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

  routing {
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
# Palo Alto Cloud NGFW (Azure managed local rulestack)
##-----------------------------------------------------------------------------
# Provides the public ingress address used by each Palo Alto Cloud NGFW in a hub.
resource "azurerm_public_ip" "palo_alto_cloud_ngfw" {
  for_each            = local.palo_alto_cloud_ngfw_hubs
  name                = format("%s-cngfw-pip", module.hub_labels[each.key].id)
  resource_group_name = var.resource_group_name
  location            = each.value.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = module.hub_labels[each.key].tags
}

# Registers the Palo Alto appliance in the Virtual Hub for firewall attachment and Routing Intent.
resource "azurerm_palo_alto_virtual_network_appliance" "cloud_ngfw" {
  for_each       = local.palo_alto_cloud_ngfw_hubs
  name           = format("%s-cngfw-nva", module.hub_labels[each.key].id)
  virtual_hub_id = azurerm_virtual_hub.main[each.key].id
}

# Creates the Azure-managed local rulestack and its security profile settings.
resource "azurerm_palo_alto_local_rulestack" "cloud_ngfw" {
  for_each              = local.palo_alto_local_rulestack_hubs
  name                  = format("%s-cngfw-rsl", module.hub_labels[each.key].id)
  resource_group_name   = var.resource_group_name
  location              = each.value.location
  description           = each.value.rulestack.description
  anti_spyware_profile  = each.value.rulestack.anti_spyware_profile
  anti_virus_profile    = each.value.rulestack.anti_virus_profile
  file_blocking_profile = each.value.rulestack.file_blocking_profile
  url_filtering_profile = each.value.rulestack.url_filtering_profile
  vulnerability_profile = each.value.rulestack.vulnerability_profile
  dns_subscription      = each.value.rulestack.dns_subscription
}

# Defines reusable network prefixes that local rulestack rules can reference.
resource "azurerm_palo_alto_local_rulestack_prefix_list" "cloud_ngfw" {
  for_each = { for item in flatten([
    for hub, config in local.palo_alto_local_rulestack_hubs : [
      for name, list in config.prefix_lists : merge(list, { hub = hub, name = name })
    ]
  ]) : "${item.hub}.${item.name}" => item }

  name          = replace(each.value.name, "_", "-")
  rulestack_id  = azurerm_palo_alto_local_rulestack.cloud_ngfw[each.value.hub].id
  prefix_list   = each.value.prefixes
  description   = each.value.description
  audit_comment = each.value.audit_comment
}

# Defines reusable FQDN destinations for local rulestack rules.
resource "azurerm_palo_alto_local_rulestack_fqdn_list" "cloud_ngfw" {
  for_each = { for item in flatten([
    for hub, config in local.palo_alto_local_rulestack_hubs : [
      for name, list in config.fqdn_lists : merge(list, { hub = hub, name = name })
    ]
  ]) : "${item.hub}.${item.name}" => item }

  name                         = replace(each.value.name, "_", "-")
  rulestack_id                 = azurerm_palo_alto_local_rulestack.cloud_ngfw[each.value.hub].id
  fully_qualified_domain_names = each.value.fqdns
  description                  = each.value.description
  audit_comment                = each.value.audit_comment
}

# Adds local rulestack certificates from Key Vault or as self-signed certificates.
resource "azurerm_palo_alto_local_rulestack_certificate" "cloud_ngfw" {
  for_each = { for item in flatten([
    for hub, config in local.palo_alto_local_rulestack_hubs : [
      for name, certificate in config.certificates : merge(certificate, { hub = hub, name = name })
    ]
  ]) : "${item.hub}.${item.name}" => item }

  name                     = replace(each.value.name, "_", "-")
  rulestack_id             = azurerm_palo_alto_local_rulestack.cloud_ngfw[each.value.hub].id
  self_signed              = each.value.self_signed
  key_vault_certificate_id = each.value.key_vault_certificate_id
  description              = each.value.description
  audit_comment            = each.value.audit_comment
}

# Associates the selected certificate with outbound TLS trust inspection.
resource "azurerm_palo_alto_local_rulestack_outbound_trust_certificate_association" "cloud_ngfw" {
  for_each = {
    for hub, config in local.palo_alto_local_rulestack_hubs : hub => config
    if config.outbound_trust_certificate_name != null
  }

  certificate_id = azurerm_palo_alto_local_rulestack_certificate.cloud_ngfw["${each.key}.${each.value.outbound_trust_certificate_name}"].id
}

# Associates the selected certificate with outbound TLS untrust inspection.
resource "azurerm_palo_alto_local_rulestack_outbound_untrust_certificate_association" "cloud_ngfw" {
  for_each = {
    for hub, config in local.palo_alto_local_rulestack_hubs : hub => config
    if config.outbound_untrust_certificate_name != null
  }

  certificate_id = azurerm_palo_alto_local_rulestack_certificate.cloud_ngfw["${each.key}.${each.value.outbound_untrust_certificate_name}"].id
}

# Creates the local rulestack security rules, including source, destination, URL, and decryption settings.
resource "azurerm_palo_alto_local_rulestack_rule" "cloud_ngfw" {
  for_each = { for rule in flatten([
    for hub, config in local.palo_alto_local_rulestack_hubs : [
      for name, rule in config.rules : merge(rule, { hub = hub, name = name })
    ]
  ]) : "${rule.hub}.${rule.name}" => rule }

  name                      = replace(each.value.name, "_", "-")
  rulestack_id              = azurerm_palo_alto_local_rulestack.cloud_ngfw[each.value.hub].id
  priority                  = each.value.priority
  action                    = each.value.action
  protocol                  = each.value.protocol
  protocol_ports            = each.value.protocol_ports
  applications              = each.value.applications
  description               = each.value.description
  enabled                   = each.value.enabled
  logging_enabled           = each.value.logging_enabled
  negate_source             = each.value.negate_source
  negate_destination        = each.value.negate_destination
  audit_comment             = each.value.audit_comment
  decryption_rule_type      = each.value.decryption_rule_type
  inspection_certificate_id = each.value.inspection_certificate_name == null ? each.value.inspection_certificate_id : azurerm_palo_alto_local_rulestack_certificate.cloud_ngfw["${each.value.hub}.${each.value.inspection_certificate_name}"].id
  tags                      = module.hub_labels[each.value.hub].tags

  dynamic "source" {
    for_each = [each.value.source]
    content {
      cidrs                           = source.value.cidrs
      countries                       = source.value.countries
      feeds                           = source.value.feeds
      local_rulestack_prefix_list_ids = source.value.local_rulestack_prefix_list_ids == null ? null : [
        for list_id in source.value.local_rulestack_prefix_list_ids : try(
          azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw["${each.value.hub}.${list_id}"].id,
          azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw["${each.value.hub}.${replace(list_id, "-", "_")}"].id,
          list_id
        )
      ]
    }
  }

  dynamic "destination" {
    for_each = [each.value.destination]
    content {
      cidrs                           = destination.value.cidrs
      countries                       = destination.value.countries
      feeds                           = destination.value.feeds
      local_rulestack_fqdn_list_ids = destination.value.local_rulestack_fqdn_list_ids == null ? null : [
        for list_id in destination.value.local_rulestack_fqdn_list_ids : try(
          azurerm_palo_alto_local_rulestack_fqdn_list.cloud_ngfw["${each.value.hub}.${list_id}"].id,
          azurerm_palo_alto_local_rulestack_fqdn_list.cloud_ngfw["${each.value.hub}.${replace(list_id, "-", "_")}"].id,
          list_id
        )
      ]
      local_rulestack_prefix_list_ids = destination.value.local_rulestack_prefix_list_ids == null ? null : [
        for list_id in destination.value.local_rulestack_prefix_list_ids : try(
          azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw["${each.value.hub}.${list_id}"].id,
          azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw["${each.value.hub}.${replace(list_id, "-", "_")}"].id,
          list_id
        )
      ]
    }
  }

  dynamic "category" {
    for_each = each.value.category == null ? [] : [each.value.category]
    content {
      custom_urls = category.value.custom_urls
      feeds       = category.value.feeds
    }
  }

  depends_on = [
    azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_fqdn_list.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_certificate.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_outbound_trust_certificate_association.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_outbound_untrust_certificate_association.cloud_ngfw,
  ]
}

# Deploys a Virtual Hub Cloud NGFW managed by its Azure local rulestack.
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack" "cloud_ngfw" {
  for_each             = local.palo_alto_local_rulestack_hubs
  name                 = format("%s-cngfw", module.hub_labels[each.key].id)
  resource_group_name  = var.resource_group_name
  rulestack_id         = azurerm_palo_alto_local_rulestack.cloud_ngfw[each.key].id
  tags                 = module.hub_labels[each.key].tags
  marketplace_offer_id = each.value.marketplace_offer_id
  plan_id              = each.value.plan_id

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id]
    virtual_hub_id               = azurerm_virtual_hub.main[each.key].id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    egress_nat_ip_address_ids    = each.value.egress_nat_ip_address_ids
    trusted_address_ranges       = each.value.trusted_address_ranges
  }

  dynamic "dns_settings" {
    for_each = each.value.dns_settings == null ? [] : [each.value.dns_settings]
    content {
      dns_servers   = dns_settings.value.dns_servers
      use_azure_dns = dns_settings.value.use_azure_dns
    }
  }

  dynamic "destination_nat" {
    for_each = each.value.destination_nat
    content {
      name     = replace(destination_nat.key, "_", "-")
      protocol = destination_nat.value.protocol

      frontend_config {
        port                 = destination_nat.value.frontend_port
        public_ip_address_id = destination_nat.value.public_ip_address_id
      }

      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_public_ip_address
      }
    }
  }

  depends_on = [
    azurerm_palo_alto_local_rulestack_rule.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_prefix_list.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_fqdn_list.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_certificate.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_outbound_trust_certificate_association.cloud_ngfw,
    azurerm_palo_alto_local_rulestack_outbound_untrust_certificate_association.cloud_ngfw,
  ]
}

# Deploys a Virtual Hub Cloud NGFW managed by Panorama.
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama" "cloud_ngfw" {
  for_each               = { for k, v in local.palo_alto_cloud_ngfw_hubs : k => v if v.management_mode == "panorama" }
  name                   = format("%s-cngfw", module.hub_labels[each.key].id)
  resource_group_name    = var.resource_group_name
  location               = each.value.location
  panorama_base64_config = each.value.panorama_base64_config
  marketplace_offer_id   = each.value.marketplace_offer_id
  plan_id                = each.value.plan_id
  tags                   = module.hub_labels[each.key].tags

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id]
    virtual_hub_id               = azurerm_virtual_hub.main[each.key].id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    egress_nat_ip_address_ids    = each.value.egress_nat_ip_address_ids
    trusted_address_ranges       = each.value.trusted_address_ranges
  }

  dynamic "dns_settings" {
    for_each = each.value.dns_settings == null ? [] : [each.value.dns_settings]
    content {
      dns_servers   = dns_settings.value.dns_servers
      use_azure_dns = dns_settings.value.use_azure_dns
    }
  }

  dynamic "destination_nat" {
    for_each = each.value.destination_nat
    content {
      name     = replace(destination_nat.key, "_", "-")
      protocol = destination_nat.value.protocol
      frontend_config {
        port                 = destination_nat.value.frontend_port
        public_ip_address_id = destination_nat.value.public_ip_address_id
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_public_ip_address
      }
    }
  }

}

# Deploys a Virtual Hub Cloud NGFW managed by Strata Cloud Manager.
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager" "cloud_ngfw" {
  for_each                         = { for k, v in local.palo_alto_cloud_ngfw_hubs : k => v if v.management_mode == "strata_cloud_manager" }
  name                             = format("%s-cngfw", module.hub_labels[each.key].id)
  resource_group_name              = var.resource_group_name
  location                         = each.value.location
  strata_cloud_manager_tenant_name = each.value.strata_cloud_manager_tenant_name
  marketplace_offer_id             = each.value.marketplace_offer_id
  plan_id                          = each.value.plan_id
  tags                             = module.hub_labels[each.key].tags

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id]
    virtual_hub_id               = azurerm_virtual_hub.main[each.key].id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    egress_nat_ip_address_ids    = each.value.egress_nat_ip_address_ids
    trusted_address_ranges       = each.value.trusted_address_ranges
  }

  dynamic "dns_settings" {
    for_each = each.value.dns_settings == null ? [] : [each.value.dns_settings]
    content {
      dns_servers   = dns_settings.value.dns_servers
      use_azure_dns = dns_settings.value.use_azure_dns
    }
  }

  dynamic "destination_nat" {
    for_each = each.value.destination_nat
    content {
      name     = replace(destination_nat.key, "_", "-")
      protocol = destination_nat.value.protocol
      frontend_config {
        port                 = destination_nat.value.frontend_port
        public_ip_address_id = destination_nat.value.public_ip_address_id
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_public_ip_address
      }
    }
  }

  dynamic "identity" {
    for_each = each.value.identity == null ? [] : [each.value.identity]
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
}

# Steers the selected Internet and/or private hub traffic through the Palo Alto appliance.
resource "azurerm_virtual_hub_routing_intent" "palo_alto_cloud_ngfw" {
  for_each       = { for k, v in local.palo_alto_cloud_ngfw_hubs : k => v if length(v.routing_policies) > 0 }
  name           = format("%s-cngfw-routing", module.hub_labels[each.key].id)
  virtual_hub_id = azurerm_virtual_hub.main[each.key].id

  dynamic "routing_policy" {
    for_each = each.value.routing_policies
    content {
      name         = routing_policy.value.name
      destinations = routing_policy.value.destinations
      next_hop     = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    }
  }

  depends_on = [
    azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack.cloud_ngfw,
    azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama.cloud_ngfw,
    azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.cloud_ngfw,
  ]
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
