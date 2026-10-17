# DevOps Assignment - Arrise

Terraform/AWS take-home assignment, 5 tasks. All account IDs, bucket names,
key pair names, repo/service names, and region (`ap-south-1`) are
placeholders - replace them before any real `apply`.

## Layout

| Directory | Task |
|---|---|
| `task1-ec2/` | 5 EC2 instances from one input variable; one io2 volume; `prevent_destroy` on the db instance; name->ID and name->private-IP outputs |
| `task2-backend/` | `backend.tf` to drop into task1 (S3 + DynamoDB locking), plus `bootstrap/` that creates the bucket and lock table once |
| `task3-iam/` | Multi-account IAM: group1 (CLI only: engine, ci), group2 (console+CLI: alice, bob), roleA (admin except IAM), roleB (assume roleC only) in Account A; roleC (one bucket only, trusted by roleB's ARN) in Account B |
| `task4-ci-policy/` | Least-privilege JSON policy for the `ci` user: ECR push to one repo, ECS deploy to one service, read-only on one artifacts bucket |
| `task5-bugfix/` | `broken.tf` (original) and `fixed/main.tf` (both bugs fixed) |
| `NOTES.md` | Explanations and design decisions per task |

## How to test

You need Terraform >= 1.5 and the AWS provider (downloaded automatically by
`init`). No AWS credentials are needed for validate/plan of the syntax, and
you should NOT run `apply` against a real account - use a throwaway account
if you want to go that far. Account IDs, bucket names, and key pair names
are placeholders.

```bash
# Validate each module without touching any backend or AWS account:
cd task1-ec2
terraform init -backend=false
terraform fmt -check
terraform validate

cd ../task2-backend/bootstrap
terraform init -backend=false && terraform validate

cd ../../task3-iam
terraform init -backend=false && terraform validate

cd ../task5-bugfix/fixed
terraform init -backend=false && terraform validate
```

Optional, with real AWS credentials for a throwaway account in place:

```bash
cd task1-ec2
terraform plan   # dry-run: shows the 5 instances it would create
```

`terraform apply` only in a throwaway account - the key pair names in
`variables.tf` must exist in that account/region first, or the apply will
fail on that check.
