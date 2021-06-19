---
layout: tapas
date: 2021-06-18
title: Encapsulation with Terraform
---

It can help to think of Terraform modules as "classes" from object-oriented languages.
One of the best aspects of classes is encapsulation—implementation details stay private,
while public methods expose functionality to clients.

A Terraform module can be structured similarly.
Consider a module that provisions an S3 bucket.
This module could output details like the ARNs of the bucket and the KMS key encrypting it;
clients would need these values to create read and write policies.
Alternatively, the module itself can define those policies and expose them (as resources or just JSON) to clients.

Advantages include:
- buckets know what functionality they allow of clients (ex. perhaps no exposed policy allows delete operations)
- easier on clients (don't need to build the policies themselves)
- reduced duplication (N clients don't need to recreate identical policies over and over)
