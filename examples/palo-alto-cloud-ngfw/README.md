# Palo Alto Cloud NGFW with Virtual WAN

This example deploys a standard Azure Virtual WAN with one hub and secures it with Palo Alto Cloud NGFW using an Azure managed local rulestack. It creates the Cloud NGFW public IP, hub virtual network appliance, local rulestack and sample security rule, firewall instance, and Internet and Private Traffic Routing Intent policies. The module also supports Panorama and Strata Cloud Manager management modes for Virtual Hub firewalls.

The key in `palo_alto_cloud_ngfw` must match a key in `hubs`. `management_mode` supports `local_rulestack` (the default), `panorama`, and `strata_cloud_manager`. Local rulestack mode accepts rules, prefix/FQDN lists, certificates, and outbound certificate associations. All modes support DNS, NAT, egress NAT addresses, trusted ranges, and Routing Intent policies. Routing policies use the names `InternetTrafficPolicy` and `PrivateTrafficPolicy`, with destinations `Internet` and `PrivateTraffic`, respectively. Palo Alto Cloud NGFW requires a Standard Virtual WAN. Configure `azurerm` with credentials that can create Virtual WAN and Palo Alto Cloud NGFW resources in a supported Azure public region.

The sample allow rule is illustrative. Review and adapt its source ranges, applications, and action to your security requirements before deployment.
