# CLAUDE.md

Terraform for mikemjharris.com on AWS. Start with README.md: it has the architecture diagram, the layers and
how changes reach production.

## This repo is public

- Never commit secrets, email addresses or personal contact details. They go in the ignored
  `terraform.tfvars` (see `terraform.tfvars.example`) or in `random_password` resources.
- Don't describe weaknesses of live systems in commits, PRs or docs.
- `.build/` (Lambda zips) and `.terraform/` are ignored; keep them out of commits.

## Running Terraform

- Always use `bin/terraform` (pinned Docker image), never a local `terraform`. Run it from inside the layer's
  folder; it picks the AWS profile from the nearest `.aws-profile`.
- Credentials: `aws sso login --sso-session mikemjharris` (add `--use-device-code --no-browser` on a headless
  machine). `terraform/github` also needs `gh auth login`.
- Save the plan and apply that file in a separate step (`plan -out=tfplan`, then `apply tfplan`), and only
  after the owner has seen the plan and said yes.
- `bin/terraform fmt -recursive` and `validate` need no credentials.

## Making changes

- `main` is protected: branch, push, open a PR. Merges are rebase-only and need the `Terraform plan` check
  (strict: the branch must be up to date). The owner merges PRs.
- Never force-push or rewrite pushed history; fix things with a new commit.
- `terraform/web/*` is applied by CI on merge. `terraform/org` (management account) and `terraform/github` are
  applied by hand, so a PR touching them needs a manual plan and apply too.
- Applies, merges, deletions and destructive AWS changes need the owner's explicit OK each time.
- Changes that need ordering (e.g. send a header before requiring it) go in separate PRs, merged one after
  the other once the first apply has finished.

## Gotchas

- `archive_file` needs `output_file_mode = "0644"`, or the zip hash differs between a local checkout and CI.
- CloudFront's managed CORS policies drop `Access-Control-Allow-Origin` when the browser sends extra request
  headers; `version.json` uses the custom `version-json-cors` policy instead.
- Budget alerts: a $1/day org budget and an anomaly alert email on unusual spend. Anything adding real cost in
  the web account can hit the $20/month kill switch (Lambdas set to concurrency 0) or the $25 `web-freeze` SCP.
- Some home routers cache old DNS; test new records with `dig @1.1.1.1` or `curl --resolve`.
- Records that other names CNAME to: check before moving or deleting them.
