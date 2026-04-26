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
