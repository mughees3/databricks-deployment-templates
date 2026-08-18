# Databricks Cloud Deployment Templates

Opinionated, **well-commented Terraform templates** for standing up a governed
Databricks environment from scratch. Built for customers to **replicate and
configure for themselves**, and structured so more clouds can be added over
time.

Each cloud is a **self-contained Terraform root** you `cd` into and run — no
hidden wiring, nothing to learn beyond standard Terraform.

> **⚠️ Unofficial / community template — not a Databricks product.**
> This is a personal, community-maintained project. It is **not** an official
> Databricks offering and is **not** supported, endorsed, or warranted by
> Databricks. It is provided **as-is, without warranty of any kind**. You are
> responsible for reviewing every resource — especially IAM scope, networking,
> and encryption — against your own organization's security and compliance
> standards before using it in production. Running these templates creates real,
> billable cloud resources in your accounts.

## Available templates

| Cloud | Status | What it provisions | Guide |
|---|---|---|---|
| **AWS** | ✅ Ready | VPC, cross-account IAM, root bucket, E2 workspace, Unity Catalog + starter catalog, SQL warehouse | [`aws/README.md`](aws/README.md) |
| **Azure** | 🟡 Planned | (VNet-injected workspace, Access Connector, UC, starter catalog) | — |
| **GCP** | 🟡 Planned | (VPC, workspace, UC, starter catalog) | — |

## Repository structure

```
databricks-cloud-templates/
├── README.md                # you are here
├── .gitignore               # keeps state & secrets out of git (repo-wide)
├── docs/
│   └── ADDING_A_CLOUD.md     # how to add azure/ or gcp/ following the pattern
├── aws/                      # ← self-contained AWS template (start here)
│   ├── *.tf                  # the template
│   ├── terraform.tfvars.example
│   ├── bootstrap/            # optional one-time remote-state setup
│   └── README.md             # step-by-step AWS guide
├── azure/                    # (future) same shape as aws/
└── gcp/                      # (future) same shape as aws/
```

Every cloud folder follows the **same conventions** so once you've learned one,
the others are familiar:

- `versions.tf` — Terraform + provider pins
- `providers.tf` — provider/auth config
- `variables.tf` — inputs with descriptions + validation
- `main.tf` + topic files (`network.tf`, `iam.tf`, `storage.tf`, …)
- `outputs.tf` — what you get back
- `backend.tf` — local by default, remote optional
- `terraform.tfvars.example` — copy → `terraform.tfvars`
- `README.md` — a beginner-friendly walkthrough

## Quick start

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars   # edit non-secret values
export TF_VAR_databricks_client_id="..."        # secrets via env vars
export TF_VAR_databricks_client_secret="..."
terraform init && terraform plan && terraform apply
```

Full instructions (prerequisites, OAuth service principal, Unity Catalog notes,
teardown, remote state, troubleshooting) are in [`aws/README.md`](aws/README.md).

## Secrets & safety

- **Never commit secrets.** Credentials are passed as `TF_VAR_*` environment
  variables; only non-secret config goes in `terraform.tfvars` (which is
  gitignored). Only the `*.example` files are committed.
- **State can contain secrets.** `*.tfstate` is gitignored. For shared use,
  enable the S3 remote backend (see each cloud's `bootstrap/`).

## Adding a new cloud

See [`docs/ADDING_A_CLOUD.md`](docs/ADDING_A_CLOUD.md). In short: copy the `aws/`
folder shape, swap the provider + resources for the target cloud's Databricks
workspace guide, keep the file names and variable conventions identical.

## References

- Databricks Terraform provider — AWS workspace guide:
  https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/aws-workspace
- Unity Catalog guide:
  https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog

---

> These templates are provided as starters for enablement/activation. See the
> unofficial/community disclaimer at the top of this README. Review IAM scope,
> networking, and encryption against your organization's standards before
> production use.
