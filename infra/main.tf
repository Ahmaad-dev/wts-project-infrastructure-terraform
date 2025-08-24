data "azurerm_client_config" "me" {}

# Data source für UAMI in fh-manuals
data "azurerm_user_assigned_identity" "mi" {
  name                = var.mi_name
  resource_group_name = var.existing_rg_name
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_key_vault" "kv" {
  name                        = var.kv_name
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = data.azurerm_client_config.me.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7
}

# KV-Secrets mit SQL-Daten
resource "azurerm_key_vault_secret" "db_host" {
  name         = "DB-HOST"
  value        = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "DB-NAME"
  value        = azurerm_mssql_database.sql_database.name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "DB-USER"
  value        = var.sql_admin_username
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_pass" {
  name         = "DB-PASS"
  value        = random_password.sql_admin_password.result
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "cae" {
  name                       = var.cae_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_storage_account" "static" {
  name                            = var.sa_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true

  static_website {
    index_document     = "base.html"
    error_404_document = "404.html"
  }
}

# Container App mit UAMI
resource "azurerm_container_app" "api" {
  name                         = var.ca_name
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.cae.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.mi.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = data.azurerm_user_assigned_identity.mi.id
  }

  ingress {
    external_enabled = true
    transport        = "auto"
    target_port      = var.api_port
    
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "backend"
      image  = "${azurerm_container_registry.acr.login_server}/machines-backend:${var.image_tag}"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "ALLOWED_ORIGINS"
        value = join(",", distinct(concat(var.allowed_origins, [azurerm_storage_account.static.primary_web_endpoint])))
      }

      env {
        name        = "DB_HOST"
        secret_name = "db-host"
      }
      
      env {
        name        = "DB_NAME"
        secret_name = "db-name"
      }
      
      env {
        name        = "DB_USER"
        secret_name = "db-user"
      }
      
      env {
        name        = "DB_PASS"
        secret_name = "db-pass"
      }
    }
    min_replicas = 1
    max_replicas = 1
  }

  # KeyVault-Secrets
  secret {
    name                 = "db-host"
    key_vault_secret_id  = azurerm_key_vault_secret.db_host.id
    identity             = data.azurerm_user_assigned_identity.mi.id
  }
  
  secret {
    name                 = "db-name"
    key_vault_secret_id  = azurerm_key_vault_secret.db_name.id
    identity             = data.azurerm_user_assigned_identity.mi.id
  }
  
  secret {
    name                 = "db-user"
    key_vault_secret_id  = azurerm_key_vault_secret.db_user.id
    identity             = data.azurerm_user_assigned_identity.mi.id
  }
  
  secret {
    name                 = "db-pass"
    key_vault_secret_id  = azurerm_key_vault_secret.db_pass.id
    identity             = data.azurerm_user_assigned_identity.mi.id
  }
}

# Rollen für die UAMI (Runtime)
resource "azurerm_role_assignment" "uami_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.mi.principal_id
}

resource "azurerm_role_assignment" "uami_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.mi.principal_id
}

resource "azurerm_role_assignment" "uami_contributor_rg" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.mi.principal_id
}

# Storage Blob Data Contributor für GitHub Actions Deployment
resource "azurerm_role_assignment" "uami_storage_blob_contributor" {
  scope                = azurerm_storage_account.static.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.mi.principal_id
}

# Role Assignment für Terraform
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.me.object_id
}

# Random password für SQL Server Admin
resource "random_password" "sql_admin_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Azure SQL Server
resource "azurerm_mssql_server" "sql_server" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.sql_admin_password.result
  
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
    Project     = "WTS-Project"
  }
}

# Azure SQL Database
resource "azurerm_mssql_database" "sql_database" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "Basic"
  zone_redundant = false

  tags = {
    Environment = "Development"
    Project     = "WTS-Project"
  }
}

# Firewall Regel für Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
