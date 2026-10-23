# NOTES

## Task 1 - which instance is protected, and why

I put `prevent_destroy` on the db instance. Simple reason: that one holds
data. If a wrong `terraform destroy` or a bad apply kills a web or worker
node, Terraform brings it back in a minute and nothing is lost. If the db
goes, the root volume goes with it, and that is real data loss, not just
downtime.

One catch: Terraform cannot switch a `lifecycle` block on and off per
`for_each` instance. So the protected instance sits in its own resource
block (`aws_instance.protected`) and the other four stay in
`aws_instance.standard`. Both are still fed from the same `var.instances`
map, so the one-input-variable requirement holds. The protection itself is
just a `protected = true` flag on that entry in the map.

## Task 2 - what happens with local state, and how the backend fixes it

With local state, every person has their own copy of the state file on
their laptop. It breaks the moment two people run `terraform apply` at the
same time:

- Both plan from the same starting state, but neither knows the other is
  running.
- Both push their changes to AWS, so you can get duplicate resources or
  changes fighting each other.
- Both write their own `terraform.tfstate` at the end, and the last write
  wins. The other run is now invisible to the state. Next plan, Terraform
  tries to create things that already exist or destroy things it thinks
  are gone.

The S3 backend puts the state in one shared place, and the DynamoDB table
adds locking. The first apply takes the lock, the second one waits for it.
Runs go one after another, nobody overwrites anybody's state, and bucket
versioning means I can still pull an older state back if something does go
wrong.

## Task 3 - the two questions

**Would I give engine and ci IAM users with long-lived access keys in a
real production setup?**

No. Long-lived access keys are one of the most common ways AWS accounts
get compromised. They end up in CI logs, laptops, repos, and they never
expire. In a real setup I would:

- Put people on IAM Identity Center (SSO) with MFA. They get short-lived
  credentials for console and CLI, and there is no password or key sitting
  around to leak.
- Give the CI pipeline an IAM role through OIDC federation (for example
  GitHub Actions' `aws-actions/configure-aws-credentials`), so every run
  gets temporary credentials instead of a stored key.

I used IAM users here only because the task asks for it. It is not what I
would pick myself.

**Why trust roleB's specific ARN instead of the Account A root in roleC's
trust policy?**

Trusting `arn:aws:iam::000000000000:root` means anyone in Account A whose
IAM permissions allow AssumeRole can take roleC. You are basically handing
the trust decision to Account A's admins.

Trusting `arn:aws:iam::000000000000:role/roleB` pins it to exactly one
identity. Even if Account A's IAM becomes permissive later, the only path
into Account B is through roleB, and roleB itself can do only that one
AssumeRole call. That keeps the blast radius as small as possible, which
is the whole point of least privilege across accounts.

## Task 4 - what I left out of the ci policy, and why

The policy covers exactly three jobs: push to one ECR repo, deploy one
task definition revision to one ECS service, and read one artifacts
bucket. What I left out:

- **Write access to the S3 bucket** - CI only reads artifacts from it.
  Whatever produces the artifacts can have its own write-scoped role.
- **Any create or delete on ECS/ECR** - the pipeline updates an existing
  service and pushes to an existing repo. It should not be able to delete
  the service, the cluster, or the repository.
- **`ecr:GetAuthorizationToken` stays `Resource: "*"`** - that action does
  not support resource-level permissions. It only returns a login token;
  the actual push is still restricted to the one repo in the next
  statement.
- **`ecs:RegisterTaskDefinition` is also `*`** - ECS does not support
  resource-level restrictions on task definition registration (there is no
  predictable ARN before the task definition exists). It is limited to
  register/describe, and the deployment itself is pinned to the one
  service ARN.
- **`iam:PassRole` pinned to the two task roles** - ECS needs PassRole to
  hand the task execution role and task role to the service. Left open, it
  would let the CI pass any role in the account and escalate, so it is
  pinned to just those two.
- **No console access, no IAM, no other services** - a CI identity should
  do its three jobs and nothing else.

## Task 5 - why the snippet was failing (my own words)

There were two separate bugs.

1. **The trust policy pointed at a principal that does not exist.** The
   principal was written as `arn:aws:iam::000000000000:user/roleB`, but
   roleB is an IAM role, so its ARN is
   `arn:aws:iam::000000000000:role/roleB`. AWS matches the principal ARN
   literally - `user/` and `role/` are not interchangeable. No identity in
   the account has the `user/roleB` ARN, so the trust matched nothing and
   every AssumeRole call from roleB was denied. Changing the path to
   `role/roleB` is what makes the trust actually resolve.

2. **The permissions policy was wide open.** `Action: "s3:*"` with
   `Resource: "*"` gives full S3 access to every bucket and object in the
   account, when the requirement was full access to one named bucket. I
   scoped it to that bucket's ARN (for bucket-level actions like listing)
   plus `bucket/*` (for object-level actions). The role keeps full access
   to that one bucket and gets nothing outside it.
