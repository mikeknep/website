---
layout: tapas
date: 2021-11-23
title: Terraform Breadcrumbs (Tags and Outputs)
---

A couple small Terraform patterns I'm trying out that are showing early promise.

### Source code location tags

Include a tag on resources to help trace them back from the AWS console to source code.
The AWS Terraform provider's `default_tags` argument is a great place for this.
If the module definition comes from a shared code repository, provide multiple tags to distinguish between the **entrypoint** and the **module** locations.

### Grouping outputs by downstream repo

One of our projects has a Terraform codebase that provisions several shared resources that are referenced by / injected into multiple downstream repos.
For example, a particular S3 bucket has three client services, and we didn't want to implicitly prioritize one of those services as the primary owner of the bucket over the others,
so the bucket definition was "lifted" to this earlier repo.
That repo now has quite a few outputs for clients to read as remote state, and it is hard to identify which outputs are used where (or if some are no longer read at all).

We're trying a new pattern where instead of exposing the outputs as a flat list, we group them into maps dedicated to each downstream repository:

```terraform
output "repo_a" {
  value = {
    hello = "world"
    hola  = "mundo"
  }
}

output "repo_b" {
  value = {
    hello   = "world"
    bonjour = "monde"
  }
}
```

A certain value can show up in multiple output maps, like `hello = "world"` does above;
such information is actually quite useful in this repo as it demonstrates that the resource truly is shared by multiple clients—if only one downstream repo uses a particular value, that value/resource may actually belong in that client repo directly.

This pattern doesn't follow the typical approach of a service being "client-agnostic",
and new clients will have to "register" themselves with the repo instead of simply using pre-existing outputs,
but I think the benefits outweigh that drawback.
Also, we aren't introducing any true _dependencies_ in the wrong direction—only naming conventions.

This approach also reminds me a bit of APIs that provide client-optimized JSON endpoints instead of one-size-fits-all REST-ful endpoints,
as discussed in [this blog post from Netflix](https://netflixtechblog.com/embracing-the-differences-inside-the-netflix-api-redesign-15fd8b3dc49d).
