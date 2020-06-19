---
layout: note
title: Terraform / AWS
---

# :thinking: :pencil: :books: :cloud:

---

Name your security groups right away.
Note that in Terraform they do have a `name` attribute (as opposed to some resources that pick up their name from a tag with key `"Name"`).
You cannot edit/modify existing security groups to update/change their name.
Consequently, if you really need to do it, you're stuck with a really tedious process:
- you want to delete the SG, but you can't delete it if anything is attached to it, so...
- you have to move attached resources to the default security group temporarily
- this is less secure, and leaves a bunch of junk around in the form of Elastic Network Interfaces

---

Always prefer separate resources to inline blocks on resources.
Main example: `aws_security_group` and `aws_security_group_rule`.
Inline blocks and separate resources will clash.
Separate resources are more extensible, particularly if you need a separate repo to create the rule.
(Why would you do that? One example is VPC peering. Imagine the connection is defined in some "neutral, third-party" codebase. That codebase should probably set the additional rules.)

---

Services define or "own" their own security groups.
Even if permissions in two different groups are identical, it's good to scope the groups to individual services.
1. This lets you know when a group is not in use
2. If you open up a VPC peering connection, it's easy to scope access by service to the peered VPC—you only need to add rules to the SG of the service that needs to be accessed.

---

A good pattern for bucket modules: create "read" and "write" policies and export their arns.
The result is a module that:
- has useful "public methods" (the policies, which multiple clients can attach to roles as needed)
- encapsulates details (no need to expose KMS keys encrypting bucket contents, policy is defined once instead of repeatedly by N clients)
