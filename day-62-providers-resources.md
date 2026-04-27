# Terraform Implicit Dependencies

## Task 3: Understanding Implicit Dependencies

Look at your `main.tf` carefully:

1. The subnet references `aws_vpc.main.id` — this is an implicit dependency
2. The internet gateway references the VPC ID — another implicit dependency
3. The route table association references both the route table and the subnet

---

## Q1: How does Terraform know to create the VPC before the subnet?

When Terraform reads `vpc_id = aws_vpc.main.id` inside `aws_subnet`, it recognises that the subnet *references* the VPC resource. This reference is an **implicit dependency** — Terraform builds an internal dependency graph and automatically infers that `aws_vpc.main` must exist before `aws_subnet.main` can be created. You never have to write `depends_on` manually for this.

---

## Q2: What would happen if you tried to create the subnet before the VPC?

AWS would reject the API call with an error like `InvalidVpcID.NotFound`, because a subnet must be attached to a real VPC. Terraform prevents this from ever happening — it always resolves the graph and creates resources in the correct order. There is no way to "force" it to create the subnet first when the reference exists.

---

## Q3: All Implicit Dependencies in the Config

| Resource | References (implicit dependency on) |
|---|---|
| `aws_subnet.main` | `aws_vpc.main.id` |
| `aws_internet_gateway.main` | `aws_vpc.main.id` |
| `aws_route_table.main` | `aws_vpc.main.id`, `aws_internet_gateway.main.id` |
| `aws_route_table_association.main` | `aws_subnet.main.id`, `aws_route_table.main.id` |

---

## Guaranteed Creation Order

Terraform enforces the following creation order based on the dependency graph:

```
aws_vpc
  ├── aws_subnet                    (parallel)
  └── aws_internet_gateway          (parallel)
        └── aws_route_table
              └── aws_route_table_association
```

`aws_vpc` → `aws_subnet` + `aws_internet_gateway` *(parallel)* → `aws_route_table` → `aws_route_table_association`


# Day 62 — Terraform Providers & Resources

> **Goal:** Provision a VPC with public subnet, internet gateway, and route table using Terraform, and understand how providers, resources, and dependencies work together.

---

## `main.tf` — Annotated

```hcl
# ─────────────────────────────────────────────────────────────
# TERRAFORM BLOCK
# Pins the required provider version so that everyone on the
# team (and CI) uses the same AWS provider binary. Without this,
# `terraform init` could silently pull a newer breaking version.
# ─────────────────────────────────────────────────────────────
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # accept 5.x but not 6.x
    }
  }
}

# ─────────────────────────────────────────────────────────────
# PROVIDER BLOCK
# Tells Terraform *where* to create infrastructure.
# The provider is a plugin that translates HCL into AWS API
# calls. Changing the region here re-targets every resource
# below with a single edit.
# ─────────────────────────────────────────────────────────────
provider "aws" {
  region = "us-east-1"
}

# ─────────────────────────────────────────────────────────────
# VPC
# The root container for all networking resources.
# enable_dns_hostnames lets EC2 instances get public DNS names,
# which is required for many services (e.g., RDS endpoints).
# ─────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "day62-vpc"
    Project = "terraform-learning"
  }
}

# ─────────────────────────────────────────────────────────────
# INTERNET GATEWAY
# Attaches to the VPC and allows traffic to/from the internet.
# Without an IGW, the VPC is completely private.
#
# IMPLICIT DEPENDENCY: the `vpc_id` attribute references
# aws_vpc.main.id, so Terraform knows the VPC must exist first.
# No `depends_on` is needed — Terraform infers the order.
# ─────────────────────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id   # <-- implicit dependency on aws_vpc.main

  tags = {
    Name    = "day62-igw"
    Project = "terraform-learning"
  }
}

# ─────────────────────────────────────────────────────────────
# PUBLIC SUBNET
# A /24 gives 256 addresses (251 usable — AWS reserves 5).
# map_public_ip_on_launch = true means any EC2 instance launched
# here gets a public IP automatically, saving us from having to
# allocate Elastic IPs manually.
#
# IMPLICIT DEPENDENCY: references aws_vpc.main.id.
# ─────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id   # <-- implicit dependency
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "day62-public-subnet"
    Project = "terraform-learning"
  }
}

# ─────────────────────────────────────────────────────────────
# ROUTE TABLE
# Defines where traffic is sent. The inline `route` block says:
# "send all non-local traffic (0.0.0.0/0) out through the IGW."
# This is what makes the subnet truly "public."
#
# IMPLICIT DEPENDENCY: references both aws_vpc.main.id and
# aws_internet_gateway.igw.id. Terraform builds a graph and
# creates the VPC and IGW before this resource.
# ─────────────────────────────────────────────────────────────
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id   # <-- implicit dependency on VPC

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id   # <-- implicit dependency on IGW
  }

  tags = {
    Name    = "day62-public-rt"
    Project = "terraform-learning"
  }
}

# ─────────────────────────────────────────────────────────────
# ROUTE TABLE ASSOCIATION
# Links the route table to the subnet. Without this step, the
# subnet uses the VPC's default route table and has no internet
# access — a common gotcha.
#
# EXPLICIT DEPENDENCY (depends_on):
# The association only makes sense after both the route table
# AND the subnet exist. Terraform could infer this from the
# attribute references, but `depends_on` is added here to
# document intent clearly and guard against future refactors
# that might break the implicit chain.
# ─────────────────────────────────────────────────────────────
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id       # implicit dep
  route_table_id = aws_route_table.public_rt.id  # implicit dep

  # Explicit dep: belt-and-suspenders; makes the ordering
  # intention visible to reviewers even without reading attrs.
  depends_on = [
    aws_route_table.public_rt,
    aws_subnet.public,
  ]
}
```

---

## `terraform apply` Output

> *The output below is representative of a successful apply for this configuration.*

```
$ terraform apply

Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_internet_gateway.igw will be created
  + resource "aws_internet_gateway" "igw" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name"    = "day62-igw"
          + "Project" = "terraform-learning"
        }
      + vpc_id   = (known after apply)
    }

  # aws_route_table.public_rt will be created
  + resource "aws_route_table" "public_rt" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + route            = [
          + {
              + cidr_block = "0.0.0.0/0"
              + gateway_id = (known after apply)
            },
        ]
      + tags             = {
          + "Name"    = "day62-public-rt"
          + "Project" = "terraform-learning"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table_association.public_assoc will be created
  + resource "aws_route_table_association" "public_assoc" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_subnet.public will be created
  + resource "aws_subnet" "public" {
      + arn                             = (known after apply)
      + availability_zone               = "us-east-1a"
      + cidr_block                      = "10.0.1.0/24"
      + id                              = (known after apply)
      + map_public_ip_on_launch         = true
      + tags                            = {
          + "Name"    = "day62-public-subnet"
          + "Project" = "terraform-learning"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + arn                              = (known after apply)
      + cidr_block                       = "10.0.0.0/16"
      + enable_dns_hostnames             = true
      + enable_dns_support               = true
      + id                               = (known after apply)
      + tags                             = {
          + "Name"    = "day62-vpc"
          + "Project" = "terraform-learning"
        }
    }

Plan: 5 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_vpc.main: Creating...
aws_vpc.main: Creation complete after 2s [id=vpc-0a1b2c3d4e5f67890]
aws_internet_gateway.igw: Creating...
aws_subnet.public: Creating...
aws_internet_gateway.igw: Creation complete after 1s [id=igw-0f1e2d3c4b5a6789]
aws_subnet.public: Creation complete after 1s [id=subnet-0123456789abcdef0]
aws_route_table.public_rt: Creating...
aws_route_table.public_rt: Creation complete after 1s [id=rtb-0abcdef1234567890]
aws_route_table_association.public_assoc: Creating...
aws_route_table_association.public_assoc: Creation complete after 0s [id=rtbassoc-0a1b2c3d4e5f6789]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

> **📸 Screenshot placeholder** — Replace this block with a screenshot of your actual terminal after running `terraform apply`.

---

## AWS Console — VPC & Resources

> **📸 Screenshot placeholder** — Capture the following views and embed them here:
>
> 1. **VPC Dashboard** → Your VPCs → `day62-vpc` detail page (shows CIDR, DNS settings)
> 2. **Subnets** → `day62-public-subnet` (shows AZ, route table association, auto-assign public IP = Yes)
> 3. **Internet Gateways** → `day62-igw` (State: Attached, VPC: `day62-vpc`)
> 4. **Route Tables** → `day62-public-rt` → Routes tab (0.0.0.0/0 → igw-xxx)
>
> *Tip: Use the **Resource Map** tab on the VPC detail page — it shows all associated resources in a single diagram.*

---

## Dependency Graph

Generated with:

```bash
terraform graph | dot -Tsvg -o graph.svg
```

### Text representation

```
digraph {
  compound = "true"
  newrank  = "true"

  subgraph "root" {
    "[root] aws_vpc.main"                             [label = "aws_vpc.main"]
    "[root] aws_internet_gateway.igw"                 [label = "aws_internet_gateway.igw"]
    "[root] aws_subnet.public"                        [label = "aws_subnet.public"]
    "[root] aws_route_table.public_rt"                [label = "aws_route_table.public_rt"]
    "[root] aws_route_table_association.public_assoc" [label = "aws_route_table_association.public_assoc"]

    // VPC has no dependencies — it is the root node
    "[root] provider[\"registry.terraform.io/hashicorp/aws\"]" -> "[root] aws_vpc.main"

    // IGW and Subnet both depend on VPC
    "[root] aws_vpc.main" -> "[root] aws_internet_gateway.igw"
    "[root] aws_vpc.main" -> "[root] aws_subnet.public"

    // Route Table depends on VPC (vpc_id) and IGW (gateway_id in route block)
    "[root] aws_internet_gateway.igw" -> "[root] aws_route_table.public_rt"
    "[root] aws_vpc.main"             -> "[root] aws_route_table.public_rt"

    // Association depends on both the RT and the Subnet
    "[root] aws_route_table.public_rt" -> "[root] aws_route_table_association.public_assoc"
    "[root] aws_subnet.public"         -> "[root] aws_route_table_association.public_assoc"
  }
}
```

### Visual (ASCII)

```
                   ┌──────────────────┐
                   │  aws_vpc.main    │  ← no dependencies; created first
                   └────────┬─────────┘
                            │
              ┌─────────────┼──────────────┐
              ▼             ▼              │
  ┌──────────────┐  ┌─────────────┐       │
  │   igw (IGW)  │  │ subnet.pub  │       │
  └──────┬───────┘  └──────┬──────┘       │
         │                 │              │
         │         ┌───────▼──────────────┘
         └────────►│  route_table.public_rt │
                   └──────────┬─────────────┘
                              │
                   ┌──────────▼──────────────┐
                   │ route_table_association  │  ← created last
                   └─────────────────────────┘
```

> **📸 Optional** — Run `terraform graph | dot -Tpng -o graph.png` and embed the rendered image here for a cleaner visual.

---

## Implicit vs Explicit Dependencies — In My Own Words

### Implicit Dependencies

An **implicit dependency** is one that Terraform discovers on its own by reading your resource attributes.

When you write `vpc_id = aws_vpc.main.id`, Terraform sees that `aws_internet_gateway.igw` needs a value that only `aws_vpc.main` can provide. It doesn't need you to tell it the order — it figures it out by tracing the reference. This is the most common kind of dependency in real Terraform code, and it's the preferred way to express relationships because the dependency is *self-documenting*: the attribute that carries the value *is* the dependency.

**In this project**, the internet gateway, subnet, and route table all carry implicit dependencies through their `vpc_id` attributes. The route table has an additional implicit dependency on the IGW because the `gateway_id` inside the `route {}` block points to `aws_internet_gateway.igw.id`.

### Explicit Dependencies (`depends_on`)

An **explicit dependency** is one you declare manually using the `depends_on` meta-argument.

You need `depends_on` when a resource depends on another resource's *side effects* — not its attributes. A classic example is an IAM role: an EC2 instance might not reference any IAM attribute directly, but it still needs the role to be fully attached before it boots, or it won't have the permissions it needs at startup. In that case, Terraform can't see the dependency by scanning attributes, so you have to spell it out.

**In this project**, `aws_route_table_association.public_assoc` already has implicit dependencies (it references both the subnet ID and the route table ID), so the `depends_on` block is technically redundant. I added it anyway as a learning exercise and as a future-proofing measure — if someone later refactors the resource to use data sources instead of direct references, the explicit dependency ensures the ordering is preserved and the intent is obvious to any reviewer.

### Quick Rule of Thumb

| Situation | Use |
|---|---|
| Resource B uses an output value from Resource A | Implicit — just reference the attribute |
| Resource B needs A's side effects but not its attributes | Explicit — add `depends_on` |
| You want to make ordering obvious for reviewers | Explicit — acceptable but document *why* |

> The Terraform docs say to use `depends_on` as a last resort, because implicit dependencies are more robust: if you rename a resource, the reference breaks loudly at plan time, whereas a stale `depends_on` entry can silently linger in the code forever.

---

*Day 62 complete ✅ — Next up: variables, outputs, and tfvars files.*
