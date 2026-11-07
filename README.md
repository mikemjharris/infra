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
| `terraform/web/sites` | web | applied, live | www, blog (Lambda), books, snowman, animated-message |
| `terraform/web/backups` | web | new | encrypted off-site backups of the Home Assistant server: private versioned bucket (90 days), upload-only `homeassistant-backup` user |
| `terraform/github` | GitHub (state in web) | applied | the site repos and `config`: rebase-only merges, secret scanning, rules on `main` (PR, CI checks, linear history), infra's `production` environment |

Each folder's `.aws-profile` names the AWS CLI profile `bin/terraform` uses there.

## Changing it

`main` is protected (in every site repo, by `terraform/github`): changes go through pull requests, merged by
rebase, and the `Terraform plan` check must pass.

- **Pull request:** GitHub Actions plans each `terraform/web/*` layer the PR touches (module changes plan
  `web/sites`) and posts the plan as a comment. It uses the read-only `github-infra-plan` role.
- **Merge to `main`:** the same layers are applied in order (bootstrap, dns, sites) in the `production`
  environment with the `github-infra-apply` role, after checking the commit is the merge of a pull request.
- **Weekly (Mondays):** every web layer is planned; the run fails if anything was changed outside Terraform.
- **`terraform/org`** (management account) isn't in CI: the CI roles live in the web account and can't reach
  it. Apply it by hand with `bin/terraform` and an SSO login to the management account.
- **`terraform/github`** isn't in CI either (it would need a GitHub token with admin on every repo). Apply it
  by hand; `bin/terraform` uses the GitHub CLI's login (`gh auth token`) and the web profile for state.
- To try things out locally: `bin/terraform plan` in a layer folder (needs `aws sso login --profile web`).

## Notes

- The `www` bucket also holds `/dashboard/` and `/lighthouse/`, which aren't in the `personal-website` repo.
  Its deploy must exclude them (`aws s3 sync --delete --exclude 'dashboard/*' --exclude 'lighthouse/*'`).
