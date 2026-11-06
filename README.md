# infra

Terraform for www.mikemjharris.com and its subdomains on AWS: static sites in S3 behind CloudFront, the blog
on Lambda, DNS in Route 53. Each site's own repo deploys its content with GitHub Actions.

- `docs/aws-migration-plan.md`: the plan for moving off the old DigitalOcean droplet.
- `bin/terraform`: runs Terraform from the pinned `hashicorp/terraform` Docker image, using AWS credentials
  from the host's AWS CLI (`aws login --profile personal`). Use it like `terraform`, from anywhere in the repo.

## Layers

| Folder | Account | State | What |
|---|---|---|---|
| `terraform/org` | management | applied | organisation, `workloads` OU, `web` account, guard-rail SCPs, SSO access, budget |
| `terraform/web/bootstrap` | web | applied | state bucket, GitHub OIDC provider, `github-infra-plan` / `github-infra-apply` roles |
| `terraform/web/dns` | web | applied, live | Route 53 zone (fixed nameservers), mail records, records for sites still on the droplet |
| `terraform/web/sites` | web | applied | `www` on S3 + CloudFront, not yet cut over |

Each folder's `.aws-profile` names the AWS CLI profile `bin/terraform` uses there.

## Notes

- The `www` bucket also holds `/dashboard/` and `/lighthouse/`, which aren't in the `personal-website` repo.
  Its deploy must exclude them (`aws s3 sync --delete --exclude 'dashboard/*' --exclude 'lighthouse/*'`).
