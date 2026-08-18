# AWS — Remote State Bootstrap (optional, one-time)

This tiny Terraform config creates the **remote backend** the main template can
use to store its state safely: an S3 bucket (versioned + encrypted) and a
DynamoDB table (state locking).

You only need this if you want **remote state** (recommended for teams/CI). If
you're just trying the template on one laptop, you can skip this entirely and
use the default local state.

## Run it

```bash
cd aws/bootstrap
terraform init
terraform apply -var="aws_region=us-west-2" -var="name_prefix=dbx"
```

Note the two outputs:

```
state_bucket = "dbx-tfstate-ab12cd"
lock_table   = "dbx-tflock-ab12cd"
```

## Wire it into the main template

1. Open `../backend.tf`, uncomment the `backend "s3"` block, and paste in the
   `state_bucket`, `lock_table`, and `region` values.
2. From the `aws/` directory run:

   ```bash
   terraform init -migrate-state
   ```

   Terraform copies your existing local state up to S3.

That's it — future `plan`/`apply` runs now use locked, shared, encrypted state.

> The bootstrap itself keeps its own state **locally** (`aws/bootstrap/terraform.tfstate`).
> That's intentional and fine: it manages only these two long-lived resources.
