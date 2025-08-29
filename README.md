# WTS Infrastructure (Terraform)
# MADE WITH AI

Provisioniert Azure-Ressourcen für das WTS-Backend.

## Komponenten
- Resource Group
- Azure Container Registry (ACR)
- Azure Container Apps Environment (CAE)
- Azure Container App (Backend)
- Azure SQL Server + Database
- (Optional) Key Vault, Storage für tfstate

## Variablen (Auszug)
- `prefix`, `location`, `rg_name`
- `acr_name`
- `cae_name`, `ca_name`
- `sql_server_name`, `sql_database_name`, `sql_admin_username`, `sql_admin_password` (oder MI + KV)
- `allowed_origins` (Liste von Frontend-URLs)
- `image_tag` (Container-Image-Tag)

## Image-Tag Update (CI)
Die GitHub Action `.github/workflows/apply-image.yml` wendet ein neues Tag an:
```yaml
jobs.apply-image.steps:
  - name: Apply new image tag
    env:
      TF_VAR_image_tag: ${{ inputs.image_tag }}
    run: terraform apply -auto-approve
