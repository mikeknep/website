---
layout: tapas
date: 2021-06-18
title: Generating Terraform
---

Terraform does not support iterating over providers.
If you need identical resources across multiple AWS accounts, or multiple AWS regions,
Terraform workspaces are a good option.
However, you may need resources in all accounts *and* all regions,
at which point workspaces alone may not be tenable.
(Cartesian products grow fast!)

We started using the `local_file` resource to use Terraform to generate more Terraform code.
Our module takes in a collection of objects and outputs a single file that maps over that collection, interpolating the values into a template.
The result is a Terraform file with many nearly-identical resources.

Our first approach was to have CI generate Terraform code in an early stage, and then plan and apply that code in later stages.
This ended up being hard to reason about, and we felt forced to push _everything_ through the generator even if it didn't seem quite necessary (ex. "generating" a single resource).

Refactored to continue to use Terraform to generate code, but checking the generated code into git.
- Easier to reason about because the full entrypoint is present in the local repo.
- Given how modules work, it's easy to mix generated and non-generated resources.
  - One `.tf` file with a bunch of generated resources, and another `.tf` file in the same directory with manually written resources
- Generally speaking: easier to **generate many files with 1-2 duplicated resources** than to **generate many duplicated resources in a single file**

Because Terraform is doing the generation, it will want to keep track of state.
But, since the generated files are being checked into git, it's advised to use git as the "true" state, and ignore the Terraform state.
In practice, this means local state + `.gitignore` + `-auto-approve`
