# NOTES

(DRAFT - rewrite these answers in your own words before submitting. Task 5
explicitly asks for your own explanation, and the reviewers will compare this
with how you talk about the work.)

## Task 1 - which instance is protected, and why

I put `prevent_destroy` on the **db** instance. It is the one whose deletion
would actually hurt: it is meant to hold data, and losing the instance (and
its root volume) by an accidental `terraform destroy` or a stray apply is a
much bigger deal than recreating a stateless web or worker node. The other
four are disposable - if one goes away, Terraform can bring it back in a
minute.

The flag is just an `protected = true` entry on that instance in the
`var.instances` map. Because Terraform cannot switch a `lifecycle` block on
and off per `for_each` instance, the protected instance gets its own resource
block (`aws_instance.protected`) and everything else stays in
`aws_instance.standard`. Both are still driven by the same single variable,
so the "one input variable" requirement holds.

## Task 2 - what happens with local state, and how the backend fixes it

With local state, each person has (at best) a copy of the same state file on
their own laptop. If two people run `terraform apply` at the same time:

- Both plans are built from the same starting state, but neither knows the
  other is running.
- Both creates/updates go to AWS independently - you can get duplicate
  resources or conflicting changes.
- Both write their own `terraform.tfstate` at the end, and the last write
  wins. The other person's run is now invisible to the state file. Next time
  either one plans, Terraform will try to create things that already exist
  or destroy things it thinks are gone.

The S3 backend moves the state to one shared, versioned location, and the
DynamoDB table adds locking: the first `apply` writes a lock record, and any
second `apply` blocks until the lock is released. Runs are serialised, the
state file can't be clobbered by a concurrent write, and versioning on the
bucket lets me recover an older state if something does go wrong.

## Task 3 - the two questions

**Would I give engine and ci IAM users with long-lived access keys in a real
production setup?**

No. Long-lived access keys on IAM users are one of the most common ways AWS
accounts get compromised - they end up in CI logs, developer laptops, and
repos, and they never expire. In a real setup I would:

- Put humans in **IAM Identity Center (SSO)** with MFA, so they get
  short-lived credentials for both console and CLI, and no passwords or keys
  to leak.
- Give the CI pipeline an **IAM role assumed through OIDC federation** (for
  example GitHub Actions' `aws-actions/configure-aws-credentials`), so the
  pipeline gets temporary credentials per run instead of a stored key.

I wrote the assignment with IAM users because that is what the task asks
for, but I would not choose it myself.

**Why trust roleB's specific ARN instead of the Account A root in roleC's
trust policy?**

Trusting `arn:aws:iam::000000000000:root` means "any principal in Account A
that its own IAM allows to call AssumeRole can take this role" - the trust
decision is delegated to Account A's administrators. Anyone (or anything) in
Account A with enough IAM permissions could assume roleC and reach the
bucket in Account B.

Trusting `arn:aws:iam::000000000000:role/roleB` pins the trust to exactly one
identity. Even if Account A's IAM gets permissive, the only path into Account
B is through roleB - and roleB's only permission is that single AssumeRole
call. It keeps the blast radius as small as possible, which is the whole
point of least privilege across account boundaries.

## Task 4 - what I left out of the ci policy, and why

The policy covers exactly the three jobs: push to one ECR repo, deploy one
task definition revision to one ECS service, and read one artifacts bucket.

What I deliberately left out:

- **Write access to the S3 bucket** - the CI only reads build artifacts from
  it. Whatever produces the artifacts can have its own write-scoped role.
- **Any delete or create permissions on ECS/ECR** - the pipeline updates an
  existing service and pushes to an existing repo; it should not be able to
  delete the service, the cluster, or the repository.
- **`ecr:GetAuthorizationToken` scoping** - this one action does not support
  resource-level permissions, so it has to be `Resource: "*"`. It only
  returns a login token; the push itself is still restricted to the one repo
  by the next statement.
- **`ecs:RegisterTaskDefinition` resource scoping** - ECS does not support
  resource-level restrictions on task definition registration (task
  definitions have no predictable ARN before they exist), so it is `*` but
  limited to register/describe. The actual deployment is pinned to the one
  service ARN.
- **`iam:PassRole` scoped to two roles** - ECS requires PassRole to hand the
  task execution role and task role to the service. Left unrestricted it
  would let the CI escalate into any role in the account, so it is pinned to
  just the two task roles.
- **No console access, no IAM, no other services** - a CI identity should do
  its three jobs and nothing else.

## Task 5 - why the snippet was failing (my own words)

There were two separate bugs.

1. **The trust policy pointed at a user that does not exist.** The principal
   was written as `arn:aws:iam::000000000000:user/roleB`, but roleB is an
   IAM *role*, not a user - its ARN is `arn:aws:iam::000000000000:role/roleB`.
   The `user/` and `role/` paths are not interchangeable; AWS matches the
   principal ARN literally. Since no identity has the `user/roleB` ARN, the
   trust policy matched nothing, so every `sts:AssumeRole` call from roleB
   was denied. Fixing the path to `role/roleB` makes the trust actually
   resolve to the role.

2. **The permissions policy was wide open.** `Action: "s3:*"` with
   `Resource: "*"` gives full S3 access to every bucket and object in the
   account - far more than "full access to a single named bucket". I scoped
   it to the one bucket ARN (for bucket-level actions like listing) plus
   `bucket/*` (for object-level actions). The role still has full access to
   that bucket, but nothing beyond it.
