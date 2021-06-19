---
layout: note
title: Terraform Chicken and Egg
---

Goals:
- manage as many resources as possible via Terraform
- execute Terraform in CI and with remote state as much as possible (preferred over local)
- avoid special cases (e.g. "the first time you run Terraform in this repo, comment out X")
- group like resources together / minimize duplication

Our solution is a humble bash script.

It uses the AWS CLI to provision **deliberately oversimplified** versions of the minimal set of resources required for remote state and CI.
For example, the S3 bucket lacks encryption, access logging, and a bucket policy;
the IAM role for manipulating state has overly-permissive `s3:*` permissions;
the CI IAM user group has admin credentials; etc.

The bash script prints `terraform import` statements for every resource it provisions.
These imports are run in other "downstream" repos or entrypoints that make the most sense for long-term management.
(Example: all IAM users with programmatic access keys are in one place to facilitate key rotation.)
Because all the remote state and CI configuration now "already exists" when those repos are first visited,
they can be executed identically the first and all subsequent times (no need to temporarily comment out backend configuration).
The first `terraform apply` in those repos will modify several of the imported resources,
"fleshing them out" to more appropriate long-term configurations.
