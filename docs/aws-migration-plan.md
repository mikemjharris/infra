# Moving mikemjharris.com to AWS

Plan written 2026-11-06 from the old `infrastructure` repo, the app repos it deploys, and the live sites.
Nothing has been changed yet.

## Summary

- Today: one DigitalOcean droplet (~$20/month) running nginx and Docker containers, set up and deployed by
  hand-run scripts (the old `infrastructure` repo). Upgrades mean patching a server and rebuilding by hand.
- Proposal: no servers at all. Static sites in S3 behind CloudFront, the blog as a Lambda function behind
  the same CloudFront, DNS in Route 53, everything defined in Terraform and deployed by GitHub Actions.
- Decided (2026-11-06): modernise **books** and **snowman** as static sites (snowman with no backend);
  retire **multi-snowman** (its code is safe on the `old-multiplayer` branch of `threejs-snowman`);
  bring **animated-message** back as a static site; Lighthouse checks move to GitHub Actions;
  infrastructure deploys by PR (plan) and merge (apply).
- Running cost: about **$1–2/month**, mostly the Route 53 hosted zone. The traffic fits inside
  AWS's always-free allowances for CloudFront, Lambda and DynamoDB.
- Four of the eleven hostnames already return errors (502), so retiring them loses nothing.

## What runs today

Checked 2026-11-06 against the live sites.

| Hostname | App (repo) | What it is | Live? | Needs a server? |
|---|---|---|---|---|
| `mikemjharris.com` | – | redirect to `www` | 301 | no |
| `www` | `personal-website` | plain HTML/JS/images | 200 | no |
| `www/dashboard` | `dashboard` | Vue app, already in S3 bucket `mj-status-dashboard` (eu-west-2), proxied by nginx | 200 | no (its status-check Lambda `nodeServerStatus` is in eu-west-1) |
| `blog` | `blog` | Express + Handlebars, server-rendered; posts are HTML files read at boot; `/mcp` endpoint; actively developed (Node 24, CI) | 200 | only for `/mcp`, see below |
| `books` | `books` | React + Express + GraphQL over a CSV bundled in the repo; Node 9 | 200 | no, if the data is pre-built |
| `snowman` | `threejs-snowman` | three.js game; socket.io only to save a high-score list to a JSON file | 200 | only for scores |
| `multi-snowman` | `threejs-snowman`, branch `old-multiplayer` | multiplayer version, HTTP only | 200 | **retire** |
| `instagram` | `insta-preview` | Node 12 app | **502** | – |
| `star-wars-timeline` | `ga-star-wars-timeline` | Rails 5.2 / Ruby 2.7 | **502** | – |
| `animated-message` | `svg-animation-with-node-server` | SVG animation page; Express only serves one template with no variables | **502** | no |
| `view-from-the-ra` | `view-from-the-ra` | Node 9 + MongoDB + Puppeteer scraper | **502** | – |
| `webhook` | `infrastructure` | deploy hook for the old box | – | replaced by CI |

Also on the box: nightly Lighthouse runs (cron) for `blog` and `www`, written into `~/lighthouse`.
DNS is hosted by DigitalOcean; mail is Google Workspace (MX → `aspmx.l.google.com`).


## Target setup

```
                       Route 53 (mikemjharris.com zone)
                                   │
         ┌─────────────────────────┼──────────────────────────┐
         ▼                         ▼                          ▼
 CloudFront: www + apex    CloudFront: blog           CloudFront: books, snowman
  │ apex → www (CF Function)  │ default → Lambda          │ (one distribution each)
  │ /dashboard/* → S3          │   (Function URL, OAC)     │
  ▼                            │ cached at the edge        ▼
 S3 (private, OAC)             ▼                          S3 (private, OAC)
                         Lambda: blog Express app
                         (Node 24, Lambda Web Adapter)
```

- **S3 buckets are private.** CloudFront reads them with Origin Access Control. Nothing is public-read.
- **TLS certificates come from ACM**, free and renewed automatically. CloudFront needs them in `us-east-1`.
- **Region:** `eu-west-2` (London) for buckets, Lambda and DynamoDB. `us-east-1` only for the ACM certificate.
- **Security headers** (HSTS, nosniff, frame options, CSP) come from a CloudFront response headers policy.
  The blog keeps its own helmet config.

### Per site

**www (personal-website).** Sync the repo to S3. Before uploading, drop `bower_components` and other dev
leftovers that don't need to be public. A CloudFront Function on the `mikemjharris.com` distribution
answers `301 → https://www.mikemjharris.com`, which replaces the nginx default server.
`/dashboard/*` becomes a second origin on the same distribution, or the dashboard files move into the
www bucket under `dashboard/`.

**blog.** Run the existing Express app unchanged in Lambda:
- Option A (recommended first): build the existing Dockerfile as a Lambda container image with the
  [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) added, and push to ECR. No code
  change. The app already reads all posts at boot and has no state, which suits Lambda well.
  CloudFront caches pages (e.g. 5 minutes, purged on deploy), so Lambda only runs on cache misses and for
  `/mcp`. Cold start is ~1s on a miss.
- Option B (later, if wanted): pre-render every route to static HTML at build time (the routes are a pure
  function of the posts), serve from S3, and keep a Lambda only for `POST /mcp`. Cheaper still and no cold
  starts, but it's a change to the blog's build.

**books (modernise).** The data is a CSV in the repo, so the GraphQL server goes: a build step turns the CSV
into JSON and the React app reads that, so the site is plain files in S3. Bring it up to date while doing so:
current Node and React, and Vite (or esbuild, like the blog) instead of webpack 3. Add a GitHub Actions build
like the blog's.

**snowman (modernise, no backend).** Static three.js game on S3. The Express server only renders one page
and relays scores over socket.io (`public/javascripts/snowman_game.js` lines 119–141), so:
- drop socket.io and the server; `snowman.html` becomes the static `index.html`
- the high-score list becomes per-player, saved in the browser's `localStorage`
- replace gulp + node-sass (deprecated, needs native builds) with Vite or esbuild + `sass`, and update three.js
- the shared leaderboard goes. If it's wanted back later, it's a small Lambda + DynamoDB.

**multi-snowman (retire).** Its code is on the `old-multiplayer` branch of `threejs-snowman`, so nothing is lost.
Delete the DNS record.

**animated-message (static).** The Express server renders one page with no template variables and serves
static files, so it becomes plain files in S3:
- `server/views/animate-message.html` becomes `index.html`
- jQuery 2.1 (via bower) is vendored or swapped for current jQuery; bower goes
- the share link's `http://` becomes `https://`
- the old `entry.json` / CouchDB dev setup is unused and can go

**instagram, star-wars-timeline, view-from-the-ra.** Already down. Retire them and
delete their DNS records. If any are worth keeping as a portfolio piece, upload a static snapshot
(screenshots + README) to S3 instead of reviving the backend.

**dashboard + `nodeServerStatus` Lambda.** It checks `version.json` on four sites, one of them dead. Either
bring the bucket and Lambda into Terraform with `import` blocks, or replace both with a scheduled GitHub
Actions uptime check and retire them.

**Lighthouse reports (decided: GitHub Actions).** A scheduled workflow in `personal-website` runs nightly:
- runs Lighthouse against `blog` and `www` on GitHub's runner, which already has Chrome
- uploads the HTML and JSON reports to the www bucket under `lighthouse/`, through the same OIDC role
  as the www deploy
- rebuilds the history index, replacing `lighthouse/list-history.sh` on the box

The blog's deploy workflow can also run it after each release. The existing history from `~/lighthouse` on the
droplet is copied into the same S3 prefix, so it carries on. Not chosen: Lambda. It needs a Chromium container
image and ~2 GB memory, and the PageSpeed Insights API gives JSON only.

**webhook.** Deleted. GitHub Actions deploys on push instead.

## Terraform

Layout in this repo:

```
terraform/
  bootstrap/           run once by hand: state bucket, GitHub OIDC provider, deploy roles
  modules/
    static-site/       S3 bucket (private) + CloudFront + OAC + ACM cert + Route 53 alias
    lambda-site/       ECR repo + Lambda (Web Adapter) + Function URL + CloudFront + cert + DNS
  main.tf              one module call per site; the Route 53 zone, MX and email TXT records
  providers.tf         aws (eu-west-2) and aws.us_east_1 alias for ACM
  backend.tf           S3 backend with use_lockfile = true (no DynamoDB lock table needed)
```

- **State:** S3 bucket with versioning and native S3 locking (Terraform ≥ 1.10).
- **Every DNS record in Terraform**, including the Google Workspace MX records, plus new SPF, DKIM and DMARC records.
- Terraform or OpenTofu both work. Terraform is the default here unless you prefer the open-source fork.

## Running Terraform locally (first)

Everything is built and checked from the command line first. The GitHub Actions workflows below are added
only once each piece works by hand.

- `bin/terraform` runs Terraform from the official Docker image (`hashicorp/terraform`, version pinned in the
  script), so nothing is installed on the machine and every run uses the same version. Run it from any
  folder in the repo.
- AWS credentials come from the AWS CLI v2 on the host: `aws login --profile personal`, or SSO. The wrapper
  passes them in as short-lived environment variables, and `~/.aws` is never mounted into the container.
- Provider downloads are cached in `~/.cache/terraform-plugins`.

## Deploying the infrastructure

Everything is deployed by `git push`, with two separate kinds of deploy.

**Infrastructure (this repo), by PR then merge:**
1. Change the Terraform on a branch and open a pull request.
2. GitHub Actions runs `terraform plan` and posts the plan as a PR comment. That is the review: exactly what will
   be created, changed or destroyed in AWS.
3. Merge to `main`. Actions checks the commit is the merge of a pull request (direct pushes are refused),
   then runs `terraform apply`.

Safety rails:
- **The apply job runs in a GitHub `production` environment.** Required reviewers on it are free on a public
  repo and optional: turned on, apply waits for a click before touching AWS (DNS and mail records live here).
- **Two AWS roles.** The plan role is read-only and is assumed on pull requests. The apply role can only be
  assumed by `main` in the `production` environment, via the OIDC `sub` claim
  `repo:mikemjharris/infra:environment:production`. Pull requests from forks get no AWS access.
- **No AWS keys or secrets in GitHub.** That matters because this repo is public. Terraform state lives in the
  private, versioned S3 bucket, never in git.
- **Branch protection on `main`** (also free on a public repo): changes go through a PR.
- **`prevent_destroy`** on the Route 53 zone, the mail records and the state bucket, and versioning on the
  state and site buckets, so a bad apply can't delete them and deploys can be rolled back.
- A scheduled `terraform plan` (weekly) flags drift, meaning anything changed by hand in the console.
- `terraform plan` can still be run locally to try things out.

**Bootstrap (once, by hand).** The pieces that the pipeline itself depends on can't deploy themselves: the state
bucket, the GitHub OIDC provider, and the plan, apply and per-app deploy roles. `terraform/bootstrap` is run once
with an admin login (`aws sso login` or the `personal` profile), keeps its own small state, and is rarely
touched after that.

## Deploying the sites (replacing the webhook)

Content deploys are separate from infrastructure and much more frequent. Terraform creates each site's
bucket or Lambda function; each app repo fills its own on push to `master`, and can't touch any other site's.
Each app repo gets a GitHub Actions workflow:

- Authenticates to AWS with **OIDC**: an IAM role per repo that trusts only that repo's `master` branch.
  No AWS keys are stored in GitHub.
- **Static sites:** build → `aws s3 sync --delete` → CloudFront invalidation.
- **Blog:** the existing CI (format, typecheck, test, smoke, Docker boot) → push image to ECR →
  `aws lambda update-function-code` → invalidate.
- `version.json` is written by the workflow from `$GITHUB_SHA` and the run time. This replaces the
  `version*.sh` scripts and fixes their bugs.

Upgrades then come down to bumping a version in a PR: Node runtime, Terraform providers, npm packages.
Dependabot or Renovate can open those PRs. There is no OS to patch.

## Cost

Rough monthly costs for a personal site's traffic, eu-west-2, list prices:

| Item | Cost |
|---|---|
| Route 53 hosted zone | $0.50 |
| Route 53 queries | < $0.10 |
| CloudFront | $0 (always-free: 1 TB out, 10M requests) |
| S3 (< 1 GB) | ~$0.03 |
| Lambda (blog) | $0 (always-free: 1M requests) |
| ECR (blog image, ~250 MB) | ~$0.03 |
| ACM certificates | $0 |
| CloudWatch logs (14-day retention) | ~$0.10 |
| **Total** | **~$1/month** vs ~$20 today |

Add an **AWS Budget** alert at $5/month (free) so a mistake or a traffic spike gets noticed. If cost must be
zero, the DNS could stay at DigitalOcean, but it can't alias the apex domain to CloudFront, so Route 53 is
worth the $0.50.

## Migration order

Each step can be done and checked on its own, and the droplet keeps serving until the DNS moves.

1. **Rescue from the droplet.** SSH in and copy off:
   - `~/lighthouse` history
   - the live server config, for reference
2. **Bootstrap AWS:**
   - state bucket, GitHub OIDC provider and deploy roles (`terraform/bootstrap`)
   - budget alert
   - check the account's root user has MFA and no access keys
3. **Route 53 zone** in Terraform, with a copy of every current record (export the zone from DigitalOcean)
   plus SPF/DKIM/DMARC. Don't switch nameservers yet.
4. **www + apex + dashboard** on S3/CloudFront. Test via the CloudFront URL.
5. **blog** on Lambda + CloudFront, with CI deploying it. Test via the CloudFront URL.
6. **books, snowman and animated-message**, modernised and built by CI into S3.
7. **Switch nameservers** at the registrar to Route 53. Lower TTLs a day before. Check mail still
   delivers, and that each hostname serves from CloudFront (`x-cache` header).
8. **Retire:**
   - delete dead hostnames
   - take a final snapshot of the droplet and destroy it
   - archive the old `infrastructure` repo

## Decisions needed

1. **The three other dead sites** (instagram, star-wars-timeline, view-from-the-ra): retire, or static snapshots?
2. **Blog:** Lambda now (option A), with pre-rendering maybe later?
3. **Dashboard:** bring under Terraform, or replace with a GitHub Actions uptime check?
4. **Which AWS account:** the existing `personal` profile that owns `mj-status-dashboard`?
5. **Where's the domain registered?** Route 53 hosts the DNS either way; transferring the registration is
   optional.
