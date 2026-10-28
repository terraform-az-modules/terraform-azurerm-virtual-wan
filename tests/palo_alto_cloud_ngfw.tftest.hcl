mock_provider "azurerm" {
  mock_data "azurerm_log_analytics_workspace" {
    defaults = {
      workspace_id         = "00000000-0000-0000-0000-000000000000"
      primary_shared_key   = "mock-primary"
      secondary_shared_key = "mock-secondary"
    }
  }
}

mock_provider "azapi" {}

variables {
  name                       = "cngfw"
  environment                = "test"
  location                   = "eastus"
  resource_group_name        = "rg-cngfw-test"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-logs/providers/Microsoft.OperationalInsights/workspaces/law-test"

  hubs = {
    eastus = {
      location            = "eastus"
      address_prefix      = "10.20.0.0/23"
      vpn_gateway_enabled = true
    }
  }

  palo_alto_cloud_ngfw = {
    eastus = {
      rulestack = {
        anti_spyware_profile = "BestPractice"
      }
      prefix_lists = {
        spokes = { prefixes = ["10.0.0.0/8"] }
      }
      rules = {
        allow_dns = {
          priority     = 100
          action       = "Allow"
          applications = ["dns"]
          protocol     = "application-default"
          source       = { local_rulestack_prefix_list_ids = ["spokes"] }
          destination  = { cidrs = ["10.20.4.100/32"] }
        }
      }
      destination_nat = {
        web = {
          protocol                  = "TCP"
          frontend_port             = 443
          backend_port              = 443
          backend_public_ip_address = "10.20.8.4"
        }
      }
      dns_settings = { dns_servers = ["10.20.4.100"] }
      routing_policies = [
        { name = "InternetTrafficPolicy", destinations = ["Internet"] },
        { name = "PrivateTrafficPolicy", destinations = ["PrivateTraffic"] },
      ]
      log_settings = {}
    }
  }
}

run "cloud_ngfw_in_hub" {
  command = plan

  assert {
    condition     = length(azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack.cloud_ngfw) == 1
    error_message = "Expected one local-rulestack Cloud NGFW."
  }

  assert {
    condition     = length(azurerm_virtual_hub_routing_intent.palo_alto_cloud_ngfw["eastus"].routing_policy) == 2
    error_message = "Expected private and internet routing policies."
  }

  assert {
    condition     = azurerm_palo_alto_local_rulestack_rule.cloud_ngfw["eastus.allow_dns"].logging_enabled
    error_message = "Rules should log by default."
  }

  assert {
    condition     = length(azapi_resource_action.palo_alto_cloud_ngfw_log_profile) == 1
    error_message = "Expected the log profile action when log_settings is set."
  }
}

run "connection_without_static_routes" {
  command = plan

  variables {
    vnet_connections = {
      lz = {
        hub                       = "eastus"
        remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet-lz"
      }
    }
  }

  assert {
    condition     = length(azurerm_virtual_hub_connection.main["lz"].routing) == 0
    error_message = "A connection without static routes keeps the hub default routing."
  }
}

run "routing_intent_blocked_by_hub_static_routes" {
  command = plan

  variables {
    vnet_connections = {
      lz = {
        hub                       = "eastus"
        remote_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet-lz"
        static_routes = [{
          name                = "spokes"
          address_prefixes    = ["10.30.0.0/16"]
          next_hop_ip_address = "10.20.4.68"
        }]
      }
    }
  }

  expect_failures = [azurerm_virtual_hub_routing_intent.palo_alto_cloud_ngfw]
}

run "policy_destination_must_match_name" {
  command = plan

  variables {
    palo_alto_cloud_ngfw = {
      eastus = {
        rulestack        = {}
        routing_policies = [{ name = "PrivateTrafficPolicy", destinations = ["Internet"] }]
      }
    }
  }

  expect_failures = [var.palo_alto_cloud_ngfw]
}

run "dnat_frontend_must_be_attached" {
  command = plan

  variables {
    palo_alto_cloud_ngfw = {
      eastus = {
        rulestack = {}
        destination_nat = {
          web = {
            protocol                  = "TCP"
            frontend_port             = 443
            public_ip_address_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/pip-other"
            backend_port              = 443
            backend_public_ip_address = "10.20.8.4"
          }
        }
      }
    }
  }

  expect_failures = [var.palo_alto_cloud_ngfw]
}
