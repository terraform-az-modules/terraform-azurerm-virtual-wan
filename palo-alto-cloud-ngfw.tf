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
      cidrs     = source.value.cidrs
      countries = source.value.countries
      feeds     = source.value.feeds
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
      cidrs     = destination.value.cidrs
      countries = destination.value.countries
      feeds     = destination.value.feeds
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
    public_ip_address_ids        = concat([azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id], each.value.additional_public_ip_address_ids)
    virtual_hub_id               = azurerm_virtual_hub.main[each.key].id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    egress_nat_ip_address_ids    = each.value.egress_nat_ip_address_ids
    trusted_address_ranges       = each.value.trusted_address_ranges
  }

  dynamic "dns_settings" {
    for_each = each.value.dns_settings == null ? [] : [each.value.dns_settings]
    content {
      dns_servers = dns_settings.value.dns_servers
      # The provider rejects use_azure_dns next to dns_servers, even as false.
      use_azure_dns = dns_settings.value.use_azure_dns ? true : null
    }
  }

  dynamic "destination_nat" {
    for_each = each.value.destination_nat
    content {
      name     = replace(destination_nat.key, "_", "-")
      protocol = destination_nat.value.protocol

      frontend_config {
        port                 = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(destination_nat.value.public_ip_address_id, azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id)
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
    public_ip_address_ids        = concat([azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id], each.value.additional_public_ip_address_ids)
    virtual_hub_id               = azurerm_virtual_hub.main[each.key].id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    egress_nat_ip_address_ids    = each.value.egress_nat_ip_address_ids
    trusted_address_ranges       = each.value.trusted_address_ranges
  }

  dynamic "dns_settings" {
    for_each = each.value.dns_settings == null ? [] : [each.value.dns_settings]
    content {
      dns_servers = dns_settings.value.dns_servers
      # The provider rejects use_azure_dns next to dns_servers, even as false.
      use_azure_dns = dns_settings.value.use_azure_dns ? true : null
    }
  }

  dynamic "destination_nat" {
    for_each = each.value.destination_nat
    content {
      name     = replace(destination_nat.key, "_", "-")
      protocol = destination_nat.value.protocol
      frontend_config {
        port                 = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(destination_nat.value.public_ip_address_id, azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id)
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
    public_ip_address_ids        = concat([azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id], each.value.additional_public_ip_address_ids)
    virtual_hub_id               = azurerm_virtual_hub.main[each.key].id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.cloud_ngfw[each.key].id
    egress_nat_ip_address_ids    = each.value.egress_nat_ip_address_ids
    trusted_address_ranges       = each.value.trusted_address_ranges
  }

  dynamic "dns_settings" {
    for_each = each.value.dns_settings == null ? [] : [each.value.dns_settings]
    content {
      dns_servers = dns_settings.value.dns_servers
      # The provider rejects use_azure_dns next to dns_servers, even as false.
      use_azure_dns = dns_settings.value.use_azure_dns ? true : null
    }
  }

  dynamic "destination_nat" {
    for_each = each.value.destination_nat
    content {
      name     = replace(destination_nat.key, "_", "-")
      protocol = destination_nat.value.protocol
      frontend_config {
        port                 = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(destination_nat.value.public_ip_address_id, azurerm_public_ip.palo_alto_cloud_ngfw[each.key].id)
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

  lifecycle {
    # Azure rejects Routing Intent while the hub default route table holds static
    # routes with a VNet connection as next hop; fail at plan time instead.
    precondition {
      condition     = length([for k, c in local.advertised_connections : k if c.hub == each.key]) == 0
      error_message = "Routing Intent on hub '${each.key}' cannot coexist with advertised static routes. Remove static_routes, or set advertise_static_routes = false, on its vnet_connections."
    }
  }

  # After the firewalls, and after the connections have dropped any static routes
  # (Azure checks for them when Routing Intent is created).
  depends_on = [
    azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack.cloud_ngfw,
    azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama.cloud_ngfw,
    azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.cloud_ngfw,
    azurerm_virtual_hub_connection.main,
  ]
}

##-----------------------------------------------------------------------------
# Palo Alto Cloud NGFW log profile
##-----------------------------------------------------------------------------
# azurerm has no argument for the firewall log profile; it is set through the
# saveLogProfile action. The workspace keys are read here and sent write-only.
data "azurerm_log_analytics_workspace" "palo_alto_cloud_ngfw" {
  count               = length(local.palo_alto_log_profile_hubs) > 0 ? 1 : 0
  name                = element(split("/", var.log_analytics_workspace_id), 8)
  resource_group_name = element(split("/", var.log_analytics_workspace_id), 4)
}

resource "azapi_resource_action" "palo_alto_cloud_ngfw_log_profile" {
  for_each    = local.palo_alto_log_profile_hubs
  type        = "PaloAltoNetworks.Cloudngfw/firewalls@2025-05-23"
  resource_id = local.palo_alto_cloud_ngfw_ids[each.key]
  action      = "saveLogProfile"
  method      = "POST"

  body = merge(
    {
      logOption = "SAME_DESTINATION"
      commonDestination = {
        monitorConfigurations = {
          id             = var.log_analytics_workspace_id
          workspace      = data.azurerm_log_analytics_workspace.palo_alto_cloud_ngfw[0].workspace_id
          subscriptionId = element(split("/", var.log_analytics_workspace_id), 2)
        }
      }
    },
    each.value.log_settings.log_type == null ? {} : { logType = each.value.log_settings.log_type }
  )

  sensitive_body = {
    commonDestination = {
      monitorConfigurations = {
        primaryKey   = data.azurerm_log_analytics_workspace.palo_alto_cloud_ngfw[0].primary_shared_key
        secondaryKey = data.azurerm_log_analytics_workspace.palo_alto_cloud_ngfw[0].secondary_shared_key
      }
    }
  }
}
