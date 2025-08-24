# Container App URL - AUSKOMMENTIERT für später
# output "container_app_url"  { value = azurerm_container_app.api.latest_revision_fqdn }
output "static_website_url" { value = azurerm_storage_account.static.primary_web_endpoint }
output "acr_login_server"   { value = azurerm_container_registry.acr.login_server }
# SQL Database Outputs - AUSKOMMENTIERT für später
# output "sql_server_fqdn"    { value = azurerm_mssql_server.sql_server.fully_qualified_domain_name }
# output "sql_database_name"  { value = azurerm_mssql_database.sql_database.name }
# Key Vault URI - AUSKOMMENTIERT für später
# output "key_vault_uri"      { value = azurerm_key_vault.kv.vault_uri }
