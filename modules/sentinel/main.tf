
# Sentinel Alert - Successful RDP Login - Win 10 HP VM 
resource "azurerm_sentinel_alert_rule_scheduled" "RDP-Alert" {
  name                       = "${var.prefix}-SuccessfulRDPLogin"
  log_analytics_workspace_id = var.law-onb-id
  display_name               = "Successful RDP Login"
  severity                   = "High"
  tactics                    = ["InitialAccess"]
  query_frequency            = "PT5M"
  query_period               = "PT5M"
  query                      = <<QUERY
SecurityEvent
| where EventID == 4624
| project TimeGenerated, Account, Computer, IpAddress, LogonType
QUERY

  timeouts {
    create = "60m"
  }

  trigger_operator    = "GreaterThan"
  trigger_threshold   = 0
  description         = "Terraform - Alert on successful RDP login"
  suppression_enabled = false

  incident {
    create_incident_enabled = true
    grouping {
      enabled = false
    }
  }

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "FullName"
      column_name = "Account"
    }
  }

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "FullName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "IpAddress"
    }
  }
  depends_on = [
    var.SenLaOb
  ]
}

#----------------------------------------------------------
# Example of setting up a data connector (adjust as needed)
#resource "azurerm_sentinel_data_connector_azure_security_center" "example" {
#  name                       = "${var.prefix}-asc-connector"
#  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.LogAnalytics.id
#}

#--------------------------------------------------------------------------------

#  Install MISP2Sentinel solution - Maybe this can be done with a Sentienl connector https://stackoverflow.com/questions/77965763/azure-sentinel-how-to-install-solution-either-using-a-cli-or-terraform
# Check  this:  https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_azure_security_center 



#--------------------------------------------------------------------------------
