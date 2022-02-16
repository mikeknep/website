---
layout: post
title: "Distributing Terraform Resources"
---

Two years ago, my client formed a "platform team" with the goal of creating a secure, consistent, and extensible cloud infrastructure environment for their multiple product teams.
The implementation included adopting [AWS Control Tower](https://aws.amazon.com/controltower/) to help manage multiple AWS accounts under one roof.

Control Tower is an opinionated collection of other AWS services, including [Organizations](https://aws.amazon.com/organizations/), [Security Hub](https://aws.amazon.com/security-hub/), [Single Sign-On](https://aws.amazon.com/single-sign-on/), and more.
Out of the box, it establishes a convention of using **account boundaries** to separate concerns—it creates three [shared accounts](https://docs.aws.amazon.com/controltower/latest/userguide/how-control-tower-works.html#what-shared) for you, and provides a mechanism for quickly vending more accounts as needed.

We embraced this concept of AWS accounts as relatively lightweight resources and ended up defining a pattern where each "product family" has their own set of AWS accounts, one per environment (e.g. development, staging, production).
This pattern has yielded a number of benefits, including limiting the blast radius should a particular account be compromised,
increasing the level of ownership each product team has over its accounts,
and controlling human user access to different parts of the overall estate at a fine-grained level.

While the product teams may differ on application languages or specific AWS services used, they share many things in common,
and the Platform Team is typically responsible for either "pre-baking" those commonalities into accounts for the teams, or at the very least providing easy ways to opt in to certain functionality consistently and securely.
For example, the engineers are all committed to using Terraform to define their infrastructure as code, so the Platform Team ensures that each account has an S3 bucket, DynamoDB table, and IAM roles for running Terraform with remote state.

The Platform Team itself is no exception to this rule; nearly everything we provision for our teams is defined in and provisioned by Terraform.
Unfortunately, distributing resources consistently across multiple "locations" (i.e. AWS accounts and/or regions) with Terraform can be quite tedious.
It typically requires manually duplicating code, which at our scale of literally dozens of accounts is unacceptable.

In this post I provide more detail into this problem, and describe two techniques we use to harness the benefits of our distributed approach, while cutting down on the tedium and avoiding excessive repetition in our codebase.

### Exploring the challenges with Terraform's `for_each`

Let's imagine we need several [SQS queues](https://aws.amazon.com/sqs/) for sending messages to consumer services.
Each queue must be encrypted with its own [KMS key](https://aws.amazon.com/kms/) for security purposes, and have a dedicated [dead letter queue](https://en.wikipedia.org/wiki/Dead_letter_queue) in case of problems like processing errors or expirations.
We can define an `encrypted_queue` module to capture the "blueprint" for a queue and all its ancillary resources that looks roughly like this (several details elided):

```terraform
# modules/encrypted_queue/main.tf

variable "name" {}

resource "aws_sqs_queue" "main" {}
resource "aws_sqs_queue" "dead_letter" {}
resource "aws_sqs_queue_policy" "main" {}
resource "aws_kms_key" "main" {}
resource "aws_kms_key_alias" "main" {}
```

Then in our entrypoint, we can provision as many of these modules as we like using Terraform's `for_each` construct:

```terraform
# main.tf

provider "aws" {
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

locals {
  queue_names = toset(["a", "b", "c"])
}

module "queues" {
  for_each = local.queue_names
  source   = "./modules/encrypted_queue"

  name = each.value
}
```

Cool! We now have three sets of production-grade queues.
Except, there's one limitation here: they're all in the same "place."
The AWS provider above specifies a role in the AWS account `111111111111`, in the `eu-west-1` (Ireland) region.
What if we want to _distribute_ encrypted queues across different accounts, or regions, or (caution: Cartesian product territory!) both?

We're definitely going to need to define multiple providers, and provision our `encrypted_queue` module with those different providers.
Unfortunately, Terraform does not currently support _iterating_ over providers.
Something like the following example **is not possible today**:

```terraform
# main.tf

provider "aws" {
  region = "eu-west-1"
  alias = "ireland"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

provider "aws" {
  region = "us-west-2"
  alias = "oregon"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

locals {
  providers = [aws.ireland, aws.oregon]
}

module "queues" {
  for_each = local.providers
  source   = "./modules/encrypted_queue"

  name = "foo" // names only need to be unique within each region

  providers = {
    aws = each.value
  }
}
```

Again, the example above is **invalid** Terraform code, but expresses what I wish was possible, as it would be the most concise declaration of what we want to provision.
Instead, it seems we are forced into typing out nearly duplicative module invocations, only changing the address and `providers` block each time:

```terraform
module "queue_ireland" {
  source = "./modules/encrypted_queue"

  name = "foo"

  providers = {
    aws = aws.ireland
  }
}

module "queue_oregon" {
  source = "./modules/encrypted_queue"

  name = "foo"

  providers = {
    aws = aws.oregon
  }
}
```

The snippet above isn't too egregious, but extending this pattern to over a dozen regions, or in our case across over 30 AWS accounts, becomes very tedious and error-prone.
Our team felt there had to be a better approach, and fortunately we found two.

### Approach 1: Terraform Workspaces

A Terraform "workspace" is a kind of context or setting in which Terraform is executed.
Technically speaking Terraform always runs in a workspace, but most of the time you are simply in the `default` workspace and don't need to think about it.
Workspaces can be listed, created, and selected via the CLI:

```
terraform workspace list
terraform workspace new $WORKSPACE
terraform workspace select $WORKSPACE
```

Each workspace has its own state file.
Terraform will automatically set up appropriate "paths" in your backend to avoid conflicts:

```terraform
# main.tf
terraform {
  backend "s3" {
    bucket = "my-s3-bucket"
    key    = "queues.tfstate"
  }
}

# State files for non-default workspaces will be located at:
# s3://my-s3-bucket/<WORKSPACE>/queues.tfstate
```

Finally, Terraform exposes the current workspace name for you to use in your Terraform code.
Say we want to create an encrypted queue in each of our supported regions, Ireland and Oregon.
We'll create a workspace for each region and use it to set the AWS provider region:

```
terraform workspace new eu-west-1
terraform workspace new us-west-2
```

```terraform
# main.tf

provider "aws" {
  region = terraform.workspace
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

module "queue" {
  source = "./modules/encrypted_queue"
  name	 = "foo"
}
```

The big catch to workspaces is added operational overhead—before every `terraform` operation (e.g. plan, apply) you must select a workspace.
Furthermore, since they have their own state files, workspaces are applied independently.
This can be either beneficial (you could "workspace by" environment to apply dev first, then staging, then production)
or tedious (confirming all workspaces are in the same state becomes a pain as their number increases and you have to continually run `terraform workspace select x && terraform plan`).

### Approach 2: Terraforming Terraform

Another approach to this problem is to generate Terraform code programmatically.
When our team began considering this and determining what language to use, and we quickly landed on a neat idea: what if we used Terraform itself to generate more Terraform code?
As an infrastructure-focused team of polyglots with very different backgrounds, the idea of maintaining a minimal "stack footprint" centered on Terraform was appealing.

The implementation details are for another blog post,
but suffice to say by using the [local_file resource](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file), the [templatefile function](https://www.terraform.io/language/functions/templatefile), and built-in looping constructs,
we defined a `generated_file` module that, given a **template** of Terraform code and a **collection** of values to fill into that template,
produces a valid Terraform file with a bunch of nearly-duplicative-but-slightly-different elements.
For example:

```terraform
# generator/main.tf

module "queues" {
  source = "./modules/generated_file"

  description   = "Encrypted queues in all our supported regions"
  output_path   = "${path.module}/../queues.tf"
  template_path = "${path.module}/queues.tftpl"

  collection = [
    { region = "eu-west-1" },
    { region = "us-west-2" },
  ]
}
```

```
# generator/queues.tftpl

provider "aws" {
  alias  = "${region}"
  region = "${region}"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

module "queue_in_${region}" {
  source = "./modules/encrypted_queue"
  name   = local.name

  providers = {
    aws = aws.${region}
  }
}
```

Produces this `queues.tf` file:

```terraform
# AUTOGENERATED
# Encrypted queues in all our supported regions

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

module "queue_in_eu-west-1" {
  source = "./modules/encrypted_queue"
  name   = local.name

  providers = {
    aws = aws.eu-west-1
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/QueueProvisioning"
  }
}

module "queue_in_us-west-2" {
  source = "./modules/encrypted_queue"
  name   = local.name

  providers = {
    aws = aws.us-west-2
  }
}
```

Notice the `local.name` in the template and generated output.
Since a Terraform module is defined by all `.tf` files in a directory, the generator can focus exclusively on the repetitive aspects and place the output file in a directory next to "normal, hand-written" Terraform code,
such as a `main.tf` file that defines the Terraform backend and shared local values.

The last decision here is whether to check in generated code, or let CI pipelines freshly generate the code each time.
We check in the generated files for two reasons: it is simpler to reason about, and simpler to run `terraform plan` locally.
That said, while the generator collection in the example above is statically defined, we do sometimes define collections dynamically using data sources or remote state that may change outside our code repository.
To ensure we don't forget to re-run the generator and check in updates, our CI pipeline includes a job that runs the generator and breaks the build if a non-zero [`git diff --exit-code`](https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---exit-code) is detected.

### Wrapping up

My team has had quite a bit of success using these two techniques to distribute resources across different accounts and regions.
We tend to prefer the generator approach for its increased flexibility and to keep everything in a single state file.
However, we do provision some resources into "all supported regions in all accounts,"
and in that case the math adds up so quickly (`regions x accounts x resources`) that we use both approaches—generate code for each region **and** define a workspace for each account—to avoid excessively large state files (which correspond to excessively long Terraform operation runtimes).

Hopefully a future version of Terraform will support iterating over providers.
There has been [some discussion](https://github.com/hashicorp/terraform/issues/24476) about it,
but there are some [tricky design constraints](https://github.com/hashicorp/terraform/issues/24476#issuecomment-700368878) involved, so in the likely long meantime, I recommend reaching for the options above.
