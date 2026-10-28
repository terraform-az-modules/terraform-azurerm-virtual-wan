provider "azurerm" {
  features {}
}

module "resource_group" {
  source      = "terraform-az-modules/resource-group/azurerm"
  version     = "1.0.4"
  name        = "secure-core"
  environment = "dev"
  location    = "eastus"
}

module "virtual_wan" {
  source              = "../../"
  name                = "secure-core"
  environment         = "dev"
  location            = module.resource_group.resource_group_location
  resource_group_name = module.resource_group.resource_group_name

  hubs = {
    eastus = {
      location       = "eastus"
      address_prefix = "10.20.0.0/23"
    }
  }

  palo_alto_cloud_ngfw = {
    eastus = {
      rulestack = {
        anti_spyware_profile  = "BestPractice"
        anti_virus_profile    = "BestPractice"
        file_blocking_profile = "BestPractice"
        url_filtering_profile = "BestPractice"
        vulnerability_profile = "BestPractice"
      }

      prefix_lists = {
        spoke_networks = {
          prefixes    = ["10.20.0.0/16"]
          description = "Connected workload address space."
        }
      }

      fqdn_lists = {
        approved_sites = {
          fqdns = ["example.com"]
        }
      }

      rules = {
        allow_web = {
          priority        = 100
          action          = "Allow"
          applications    = ["web-browsing", "ssl"]
          protocol        = "application-default"
          source          = { local_rulestack_prefix_list_ids = ["spoke_networks"] }
          destination     = { cidrs = ["0.0.0.0/0"] }
          logging_enabled = true
          description     = "Allow web traffic from connected networks."
        }
      }

      routing_policies = [
        { name = "InternetTrafficPolicy", destinations = ["Internet"] },
        { name = "PrivateTrafficPolicy", destinations = ["PrivateTraffic"] },
      ]
    }
  }
}
