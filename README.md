# infra

Terraform for www.mikemjharris.com and its subdomains on AWS: static sites in S3 behind CloudFront, the blog
on Lambda, DNS in Route 53. Each site's own repo deploys its content with GitHub Actions.

- `docs/aws-migration-plan.md`: the plan for moving off the old DigitalOcean droplet.
- `bin/terraform`: runs Terraform from the pinned `hashicorp/terraform` Docker image, using AWS credentials
  from the host's AWS CLI (`aws login --profile personal`). Use it like `terraform`, from anywhere in the repo.

Status: planning; nothing is deployed from here yet.
