# Screenshot of today's session
![alt text](day-61(terra-week).png)
![alt text](day-61(1).png)


## What is Infrastructure as Code (IaC)? Why does it matter in DevOps?
### Iac is the way/techology to build infrastructre by code Declarative means you describe what you want (e.g., "I want 3 servers"), not how to create it. Terraform figures out the steps — you don't write the logic.


## What problems does IaC solve compared to manually creating resources in the AWS console?
### The problem is that you have to first login, set your desired resource manually which takes a lot of time. And you also have to repeat this practise each time you need those resources. But in IaC , you can just write a code which acts as a base and gives you your resources with only a single command.


## How is Terraform different from AWS CloudFormation, Ansible, and Pulumi?
## Terraform vs CloudFormation: Terraform is multi-cloud and open-source; CloudFormation is AWS-only. Use CloudFormation if you're purely on AWS, Terraform if you need multiple cloud providers.
### Terraform vs Ansible: They do different things — Terraform provisions infrastructure, Ansible configures what's on it. They're commonly used together, not as replacements for each other.
### Terraform vs Pulumi: Same idea, different language. Terraform uses HCL, Pulumi lets you write infrastructure in Python, TypeScript, Go, etc. Terraform is more mature; Pulumi suits dev teams who want real programming languages over a DSL.

## What does it mean that Terraform is "declarative" and "cloud-agnostic"?
### Declarative means you describe what you want (e.g., "I want 3 servers"), not how to create it. Terraform figures out the steps — you don't write the logic.
### Cloud-agnostic means the same Terraform code structure works across AWS, GCP, Azure, etc. You swap providers without relearning the tool.

## How does Terraform know the S3 bucket already exists and only the EC2 instance needs to be created?
### Terraform knows through its state file (terraform.tfstate).
### When you first apply, Terraform records every resource it created into the state file.
### Terraform compares your config against the state file and sees the S3 bucket already exists and matches — so it skips it and only creates the EC2 instance.
