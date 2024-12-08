terraform {
  # Configure the Azure provider
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.13.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  subscription_id = "b143ccd3-663b-4d1a-9f91-1f9bf62c36c5"
  features {
  }
}
# Generate random int
resource "random_integer" "ri" {
  min = 10000
  max = 99999

}
# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}${random_integer.ri.result}"
  location = var.resource_group_location
}
# Create the Linux App Service Plan
resource "azurerm_service_plan" "dimoasp" {
  name                = "${var.app_service_plan_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}
# Create the web app, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "dimoalwa" {
  name                = "${var.app_service_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.dimoasp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.mssqldb.name};User ID=${azurerm_mssql_server.sqlserver.administrator_login};Password=${azurerm_mssql_server.sqlserver.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_mssql_server" "sqlserver" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "mssqldb" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sqlserver.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "S0"
  zone_redundant = false
}

resource "azurerm_mssql_firewall_rule" "firewall" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Deploy code from a public Github repo
resource "azurerm_app_service_source_control" "github" {
  app_id                 = azurerm_linux_web_app.dimoalwa.id
  repo_url               = var.repo_url
  branch                 = "main"
  use_manual_integration = true
}