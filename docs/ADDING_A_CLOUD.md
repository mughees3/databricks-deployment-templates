# Adding a New Cloud (Azure / GCP / …)

This repo uses **flat, per-cloud Terraform roots**. Each cloud is independent —
there is no shared module layer to reason about. To add a cloud, you replicate
the proven `aws/` shape and swap in that cloud's Databricks workspace resources.

## The pattern (keep it identical across clouds)

Create a new top-level folder (`azure/` or `gcp/`) with these files:

| File | Purpose |
|---|---|
| `versions.tf` | Pin Terraform + the `databricks` and cloud provider versions |
| `providers.tf` | Configure the cloud provider + the Databricks **account** and **workspace** providers |
| `variables.tf` | Inputs with `description` and `validation`; mark secrets `sensitive` |
| `main.tf` | `locals` (naming/tags) + the workspace resource |
| topic files | e.g. `network.tf`, `identity.tf`, `storage.tf`, `unity_catalog.tf` |
| `workspace_resources.tf` | Starter warehouse, admin grants |
| `outputs.tf` | `workspace_url`, ids, buckets/containers |
| `backend.tf` | Local by default; remote (blob/GCS) optional |
| `terraform.tfvars.example` | Copy → `terraform.tfvars`; non-secrets only |
| `bootstrap/` | One-time remote-state store for that cloud |
| `README.md` | Beginner walkthrough mirroring `aws/README.md` |

### Conventions to preserve
- **Secrets via `TF_VAR_*` env vars**, never in committed files.
- **Non-secrets via `terraform.tfvars`** (gitignored; only `*.example` committed).
- **Random suffix** in `locals.name` for globally-unique names.
- **Two Databricks providers**: one for the account/management API, one
  workspace-scoped (used only after the workspace exists).
- **Heavy comments** — these templates are teaching tools.

## Cloud-specific starting points

### Azure
- Provider: `hashicorp/azurerm` + `databricks/databricks`.
- Workspace: `azurerm_databricks_workspace` (VNet injection via `custom_parameters`).
- Account/Databricks auth: Azure AD; the account console is
  `accounts.azuredatabricks.net`.
- Unity Catalog storage: ADLS Gen2 container + **Access Connector**
  (`azurerm_databricks_access_connector`) instead of an IAM role.
- Guide: databricks/databricks provider → *Azure workspace* + *Unity Catalog* guides.

### GCP
- Provider: `hashicorp/google` + `databricks/databricks`.
- Workspace: `databricks_mws_workspaces` with `cloud = "gcp"` and a GKE/network config.
- Account console: `accounts.gcp.databricks.com`.
- Unity Catalog storage: a GCS bucket + a Databricks-managed service account.
- Guide: databricks/databricks provider → *GCP workspace* guide.

## Recommended workflow to add a cloud

1. `cp -r aws azure` (then delete AWS-specific `iam.tf`/`storage.tf` bodies).
2. Rewrite `providers.tf` for the new cloud's auth.
3. Replace networking + identity + storage resources per that cloud's guide.
4. Keep `unity_catalog.tf`, `workspace_resources.tf`, `outputs.tf` structure;
   swap the storage-credential mechanism (Access Connector / GCP SA).
5. Update `terraform.tfvars.example` and `README.md`.
6. Add a row to the table in the root `README.md`.

Keeping the file names and variable names identical is what makes the repo easy
for customers to navigate across clouds.
