---
layout: note
title: Terraform / AWS
---

## :thinking: :pencil: :books: :cloud:

---

Embrace IAM roles!

`terraform backend` block and `provider "aws"` blocks both optionally take role ARNs.
These roles _do not need to be the same_.
Terraform will use different roles for different parts of its operation.
The provider role is used to create, update, and destroy AWS resources.
The backend role is used to read and record the state(s) of those resources before and after that work.
So, you can define a role that only has access to read and write to your Terraform remote state bucket _and do nothing else_.
We even set up `TerraformRemoteStateReadWrite` and `TerraformRemoteStateRead` (only) roles, the latter used for looking up values via `terraform_remote_state`.

Going "up a level," the credentials used to run `terraform apply` only need the ability to assume the roles used in the Terraform blocks.
In our case, these creds are either:
- static/long-lived programmatic access keys belonging to an IAM user used exclusively in our CI environment
- ephemeral/short-lived programmatic access keys acquired by an SSO user assuming a role in an account

---

Services defining / "owning" their own security groups has proven a useful pattern.
Even if permissions in two different groups are identical, it's good to dedicate groups to individual services.
1. This lets you easily know when a group is not in use and can be removed
2. If you open up a VPC peering connection (see below), it's easy to scope access within the peered VPC to individual services instead of opening up, say, every service in the private subnets;
you only add new ingress rules to the security group of the service that needs to be accessed.

---

A good pattern for bucket modules: create "read" and "write" policies and export their arns.
The result is a module that:
- has useful "public methods" (the policies, which multiple clients can attach to roles as needed)
- encapsulates details (no need to expose KMS keys encrypting bucket contents, policy is defined once instead of repeatedly by N clients)

That said, S3 buckets tend to have frustratingly subtle differences that prevent defining a single shared module.
Examples include:
- encryption (prefer KMS, but some situations require the default AES256)
- cross-account access (trusted principals on the bucket's policy)
To combat this, focus on creating many small modules that can be composed together.
- client read/write policies
- bucket policy statements (require SSL, open cross-account access, etc.)
- kms key with alias and default policy

---

Always prefer separate resources to inline blocks on resources.
Main example: `aws_security_group` and `aws_security_group_rule`.
Inline rule blocks and separate rule resources will clash.
Separate resources are more extensible, particularly if you need a separate repo to create the rule.
Why would you do that?
One example is VPC peering.
We manage all VPC peering connections in a single repository to 1) share boilerplate Terraform code and 2) keep track of them all in one place (which can be especially important given the potential for overlapping CIDR ranges).
Peering connections are established to serve some purpose—service A needs access to service B.
The security group rules required to support that connection are directly related to the connection itself—there is no use in having one without the other.
Therefore we want that "neutral, third-party" codebase to define the rules alongside the connection as a single, cohesive "unit".

---

**Generating** Terraform code.
Useful workaround while Terraform does not support iterating over _providers_.
(Workspaces are also good for this, but sometimes the right dimension for the workspace requires duplicative code.
Example dependencies between AWS accounts may mean AWS regions are the right workspace dimension,
but the resources going into each account need to be duplicated.)

First approach was to have CI generate Terraform code in an early stage, and then plan and apply that code in later stages.
This ended up being hard to reason about, and we felt forced to push _everything_ through the generator even if it didn't seem quite necessary (ex. "generating" a single resource).

Refactored to continue to use Terraform to generate code, but checking the generated code into git.
- Easier to reason about because the full entrypoint is present in the local repo.
- Given how modules work, it's easy to mix generated and non-generated resources.
  - One `.tf` file with a bunch of generated resources, and another `.tf` file in the same directory with manually written resources
- Generally speaking: easier to **generate many files with 1-2 duplicated resources** than to **generate many duplicated resources in a single file**

Because Terraform is doing the generation, it will want to keep track of state.
But, since the generated files are being checked into git, it's advised to use git as the "true" state, and ignore the Terraform state.
In practice, this means local state + `.gitignore` + `-auto-approve`
