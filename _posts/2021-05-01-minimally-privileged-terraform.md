---
layout: post
title: "Minimally Privileged Terraform"
---

By default, every newly created AWS resource lacks permission to perform any actions.
AWS strongly recommends following the security practice of granting _least privilege_, i.e. the minimum set of permissions necessary to perform a given task.
In many cases, this is fairly straightforward: for example, a Lambda function might only need to write to a particular SNS topic, or a group of users requires read-only permissions to certain S3 buckets.

Least privilege is trickier when defining what permissions to grant an automation user that is running Terraform in CI.
At first it seems this user would require expansive admin permissions, since it is managing the entire infrastructure.
However, over the past year our team has developed several strategies to scope down the permissions available to Terraform.
This ultimately reduces the potential blast radius should any particular set of credentials be compromised.
In this post I'll outline the evolution of how we operate Terraform with fewer and fewer privileges while maintaining the ability to adapt to changes in required permissions.

### Admin user

We'll start with an IAM user with programmatic access keys (i.e. `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) and the AWS-managed `AdministratorAccess` permissions policy.
Having _any_ identities like this in your AWS environment is a red flag, whether they are used by automated processes or human developers.
Programmatic access keys can be deleted, but not automatically by AWS, so unless deliberate action is taken on them, they are as valid today as they were last week and will be next month.
If they become compromised, a nefarious actor can use them for as long as they want until someone notices and revokes them.
And if admin permissions are attached directly to that user, the bad actor can cause all sorts of mayhem.

Let's score a big win quickly by switching to using **roles**.

### Admin role

Like users, IAM roles are identities to which various permissions can be attached.
The main difference is that rather than mapping directly to a person or resource (e.g. a specific developer, or a specific automated process), roles exist independently and can be _assumed_ by other identities.
When a user assumes a role, they effectively "trade" their permissions for those of the role (they are not "merged with" or "added on top of" the user's own permissions).
This action is performed via the Security Token Service (STS), and looks like this:

```
> aws sts assume-role --role-arn arn:aws:iam::123:role/terraform-admin --role-session-name mike-running-terraform --external-id tf-admin

{
  "Credentials": {
    "AccessKeyId": "ASIA********",
    "SecretAccessKey": "********",
    "SessionToken": "***********",
    "Expiration": "2021-04-14T20:45:00+00:00"
  },
  "AssumedRoleUser": {
    "AssumedRoleId": "*****:mike-running-terraform"
    "Arn": "arn:aws:sts::123:assumed-role/terraform-admin/mike-running-terraform"
  }
}
```

The request provides the ARN of a role to be assumed (`terraform-admin`), the role's external ID (`tf-admin`, a sort of "password" roles can require of their clients), and a "session name" (`mike-running-terraform`, which we use as a human-recognizable description of why the role assumption is happening).
In response, we receive a new set of credentials that look similar to our static IAM user creds—we see an access and secret key in there—**but** they include an expiration time, which means if _these_ credentials get exposed somewhere, they'll at least be automatically invalidated quickly (the default duration is one hour).

This is a win on its own—ephemerality is good, and roles are generally more reusable than user credentials—but becomes particularly valuable when we adjust our original IAM user credentials in response.
Those user access keys are still static, and there's nothing we can do about that, but we _can_ significantly reduce the permissions associated with that user.
In fact, the _only_ action that user needs is `sts:AssumeRole`.
With that one permission, they can use their static creds to immediately assume higher-privileged but ephemeral credentials (provided they know the ARN and external ID).

### Separate roles

Next let's take a look at some Terraform mechanics.
By default, Terraform will use the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables for its AWS API calls.
We don't want to have to manually update our CI/CD environment variables every hour, so we will use the long-lived, static credentials attached to the IAM user.
Our CI/CD process could first call `aws sts assume-role` and export those credentials into the environment for Terraform to use, but Terraform's AWS provider and S3 backend configuration have native support for this:

```
terraform {
  backend "s3" {
    # details elided
    role_arn    = "arn:aws:iam::123:role/terraform-admin"
    external_id = "tf-admin"
  }
}

provider "aws" {
  region = "us-west-2"
  assume_role {
    role_arn    = "arn:aws:iam::123:role/terraform-admin"
    external_id = "tf-admin"
  }
}
```

Notice that we've defined the role details in two places.
If we back up a moment and think about Terraform at a higher level, we'll remember that Terraform works with all kinds of cloud services and APIs, not just AWS.
We're all-in on AWS in this example (and on our current project), but others are using Terraform to provision, say, Azure resources, and storing the infrastructure configuration state in a Terraform Cloud backend.

Given this support for mixing and matching services, we can conclude that Terraform must be able to use different credentials for different operations.
Specifically, _provisioning resources_ is distinct from from _recording the states of those resources_.
We can therefore create separate `terraform-state` and `terraform-provisioning` roles;
the former only needs read and write access to the S3 bucket where we store our state—a really nice, tightly defined single responsibility!
The latter requires CRUD permissions on whatever resources we're provisioning in our account, e.g. ECS, RDS, Route53, etc.
At least, for now.

### Smaller and smaller provisioning roles

On my current project, our infrastructure code is distributed across many repositories.
Generally speaking, each service defines its own infrastructure.
This gives us an opportunity to further break apart the `terraform-provisioning` role above into finer-grained roles like `public-api-provisioning` and `etl-processor-provisioning`, which likely do not use the same AWS products nor therefore need identical permissions.
We're getting further and further away from any one set of credentials being capable of wreaking havoc across the account: the user can only assume roles for which they know both the ARN and external ID in advance, and each of those roles can only directly affect isolated resources and services for brief amounts of time.

We're continuing to push the limits of this strategy.
Our latest idea involves shipping provisioning roles with our organization-wide shared Terraform modules.
We predict this will yield a few benefits.
First, knowing which permissions are required to provision a set of resources is not always easy.
IAM actions are very fine-grained, and the process of setting up provisioning roles can be quite tedious as you partially apply a module again and again, running into yet another missing permission each time.
Including a provisioning role "out of the box" alongside the module itself should make clients' lives simpler.
Second, this would continue slicing the permissions smaller and smaller—in this case, not stopping at the level of a service but going deeper to individual components of a service.
(The tradeoff here is eventually managing quite a few Terraform providers, but we already often pass around more than one for other technical reasons.)

Another idea under consideration is omitting delete permissions from roles most of the time, and only adding them in temporarily when needed for specific operations and revoking them afterwards.
This strategy may prove to be useful in production accounts but too great a hassle in development, where more experimental iteration occurs.

Finally, we are excited to explore the [latest features of IAM Access Analyzer](https://aws.amazon.com/blogs/security/iam-access-analyzer-makes-it-easier-to-implement-least-privilege-permissions-by-generating-iam-policies-based-on-access-activity/),
which can now generate IAM policies based on access activity.
Perhaps a new workflow may involve using a fairly permissive role in development to get an MVP initially deployed to AWS, followed by having IAM Access Analyzer generate a more appropriate role policy to use for production deployments.
