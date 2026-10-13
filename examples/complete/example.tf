provider "azurerm" {
  features {}
}

module "resource_group" {
  source      = "terraform-az-modules/resource-group/azurerm"
  version     = "1.0.4"
  name        = "core"
  environment = "dev"
  location    = "westus3"
  label_order = ["name", "environment", "location"]
}

module "vnet" {
  source              = "terraform-az-modules/vnet/azurerm"
  version             = "1.0.4"
  name                = "core"
  environment         = "dev"
  label_order         = ["name", "environment", "location"]
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  address_spaces      = ["10.10.4.0/22"]
}

##-----------------------------------------------------------------------------
## Virtual WAN with one hub, a VPN site and a virtual network connection
##-----------------------------------------------------------------------------
module "virtual_wan" {
  source              = "../../"
  name                = "core"
  environment         = "dev"
  location            = module.resource_group.resource_group_location
  resource_group_name = module.resource_group.resource_group_name

  hubs = {
    westus3 = {
      location            = "westus3"
      address_prefix      = "10.10.0.0/23"
      vpn_gateway_enabled = true
    }
  }

  vpn_sites = {
    office = {
      hub = "westus3"
      links = [{
        name       = "primary"
        ip_address = "203.0.113.10"
        bgp        = { asn = 65010, peering_address = "169.254.21.1" }
      }]
    }
  }

  vnet_connections = {
    core-westus3 = {
      hub                       = "westus3"
      remote_virtual_network_id = module.vnet.vnet_id
      static_routes = [{
        name                = "spokes-via-nva"
        address_prefixes    = ["172.20.0.0/18"]
        next_hop_ip_address = "10.10.5.4"
      }]
    }
  }
}
