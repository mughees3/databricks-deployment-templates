# Databricks on AWS — Terraform Template

Provision a complete, governed Databricks environment on AWS from scratch:

- A **customer-managed VPC** (subnets, NAT, security group, VPC endpoints)
- The **cross-account IAM role** Databricks uses to run compute in your account
- The **workspace root S3 bucket** (locked down + encrypted)
- A **Databricks E2 workspace**
- **Unity Catalog**: metastore, storage credential, external location, and a starter catalog
- **Starter resources**: a small SQL warehouse and workspace-admin grants

It's built to be **read, understood, and copied** — every file is heavily
commented and each concern lives in its own `.tf` file.

---

## 1. What you need before you start (prerequisites)

| Requirement | How to get it |
|---|---|
| **Terraform ≥ 1.5** | `brew install terraform` (macOS) or see terraform.io/downloads |
| **AWS account + admin-ish credentials** | Ability to create IAM roles, VPCs, and S3 buckets |
| **AWS CLI configured** | `aws configure` (or SSO). Test with `aws sts get-caller-identity` |
| **A Databricks account on AWS** | The E2 account at `accounts.cloud.databricks.com` |
| **Databricks Account ID** | Account console → top-right menu |
| **An account-level OAuth service principal** | Account console → Settings → Identity → Service principals → add one → generate an **OAuth secret** (client_id + client_secret). Give it the **Account admin** role so it can create workspaces + metastores |

> **One metastore per region.** Unity Catalog allows a single metastore per AWS
> region per Databricks account. If your account already has one in your target
> region, set `create_metastore = false` and provide `existing_metastore_id`
> (see step 3).

### Pre-flight checklist — the things that actually block an apply

These aren't code issues; they're environmental. Check them before you run:

- [ ] **Databricks service principal is an *Account admin*** — it must be able to
      create workspaces and a metastore. (The template makes it a *workspace*
      admin automatically; it can't grant itself *account* admin.)
- [ ] **AWS creds can create IAM roles, VPCs, and S3 buckets** — an admin or
      equivalent policy. Cross-account role creation is the usual permission gap.
- [ ] **AWS service quotas in the target region** (default account limits are low):
      - **VPCs per region** (default **5**) — a busy sandbox may be maxed out.
      - **Elastic IPs per region** (default **5**) — the NAT gateway needs one.
      - **NAT gateways per AZ** — one is created by default.
- [ ] **Region supports Databricks E2 + Unity Catalog** — use a mainstream region
      (us-west-2, us-east-1, eu-west-1, ap-southeast-2).
- [ ] **Serverless SQL**: leave `sql_warehouse_serverless = false` unless you've
      confirmed serverless SQL is enabled for the account/region.
- [ ] **`workspace_admins` emails already exist as account users** — the lookup
      fails on unknown users. Leave the list empty to skip.

---

## 2. Understand the layout

```
aws/
├── versions.tf              # Terraform + provider version pins
├── providers.tf             # AWS + Databricks (account & workspace) providers
├── variables.tf             # All inputs, with descriptions & validation
├── main.tf                  # Locals + the workspace resource (the keystone)
├── network.tf               # VPC, subnets, security group, VPC endpoints
├── iam.tf                   # Cross-account IAM role Databricks assumes
├── identity.tf              # Grants the provisioning SP admin on the workspace
├── storage.tf               # Workspace root S3 bucket + policy
├── unity_catalog.tf         # Metastore, storage credential, catalog
├── workspace_resources.tf   # Starter SQL warehouse + admin grants
├── outputs.tf               # Values printed after apply
├── backend.tf               # State backend (local by default; S3 optional)
├── terraform.tfvars.example # Copy → terraform.tfvars and edit
└── bootstrap/               # One-time remote-state setup (optional)
```

Terraform figures out the correct build **order** automatically from the
dependencies between resources — you never run these in sequence by hand.

---

## 3. Configure

**Non-secret values** go in a tfvars file. **Secrets** go in environment
variables so they're never written to disk in the repo.

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: account id, region, prefix, tags, catalog name...
```

Then export the two secrets (the OAuth service-principal credentials):

```bash
export TF_VAR_databricks_client_id="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export TF_VAR_databricks_client_secret="dose..."     # from the OAuth secret you generated
```

> Terraform automatically maps `TF_VAR_<name>` env vars to input variables. The
> `client_secret` variable is marked `sensitive`, so it won't print in logs.

If your account already has a metastore in the region, edit `terraform.tfvars`:

```hcl
create_metastore      = false
existing_metastore_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
```

---

## 4. Deploy

```bash
terraform init      # download providers + the VPC module
terraform plan      # review EXACTLY what will be created — read this!
terraform apply     # type "yes" to build it (~10–15 min, mostly the workspace)
```

When it finishes you'll see outputs including your **workspace_url**. Open it,
log in, and you'll find the starter catalog and SQL warehouse ready to go.

Retrieve outputs anytime:

```bash
terraform output
terraform output -raw workspace_url
```

---

## 5. Tear it down

```bash
terraform destroy
```

Buckets are created with `force_destroy = true` so a starter environment cleans
up fully. (For production you'd set that to `false` to protect data.)

---

## 6. Remote state (recommended for teams/CI)

By default state is **local** (`terraform.tfstate` in this folder) — simplest for
a first run. For anything shared, use the S3 backend:

1. Create the backing store once: see [`bootstrap/README.md`](bootstrap/README.md).
2. Uncomment + fill the `backend "s3"` block in `backend.tf`.
3. `terraform init -migrate-state`.

---

## 7. Pointing this at your own standards

This is a **starter**. Common next changes:

- **Networking**: bring your own VPC by replacing `network.tf` with data
  sources for existing subnets/SG, then feed those IDs to `databricks_mws_networks`.
- **PrivateLink / no public IPs**: add back-end/front-end VPC endpoints and set
  the workspace to private access. (Ask for the PrivateLink variant.)
- **HA NAT**: set `single_nat_gateway = false` in `network.tf` for one NAT per AZ.
- **More catalogs/schemas/grants**: extend `unity_catalog.tf` and
  `workspace_resources.tf`.
- **Customer-managed keys (CMK)**: add `databricks_mws_customer_managed_keys`.

---

## 8. Common pitfalls

| Symptom | Cause / Fix |
|---|---|
| `METASTORE_ALREADY_EXISTS` or metastore assign fails | Region already has a metastore → `create_metastore = false` + `existing_metastore_id`. |
| `AuthorizationError` creating IAM | Your AWS creds lack IAM permissions. Use an admin role. |
| Workspace stuck / credential validation fails | IAM role propagation delay — re-run `apply`; the `depends_on` usually handles it. |
| `default credentials` errors for Databricks | You didn't export `TF_VAR_databricks_client_id/secret`, or the SP lacks Account admin. |
| `PERMISSION_DENIED` on catalog / storage credential / warehouse | The provisioning SP isn't a workspace admin. `identity.tf` handles this automatically — ensure it applied and re-run. |
| SQL warehouse creation fails / serverless not available | Set `sql_warehouse_serverless = false` (classic PRO works everywhere). |
| `cannot read user` for a workspace admin | An email in `workspace_admins` isn't an account user yet. Remove it or invite them first. |
| `LimitExceeded` on VPC or Elastic IP | AWS quota hit — see the pre-flight checklist. Request a quota increase or clean up unused VPCs/EIPs. |
| Bucket name already exists | S3 names are global; the random suffix normally avoids this — re-run to get a new suffix. |

---

See the [repository README](../README.md) for the multi-cloud structure and how
to add Azure / GCP templates.
