# Scan Infra Exercise (DevOps)

Thanks for spending time on this. The take-home should take **about 2 hours** plus setup. Please don't go over 2½.

## The scenario

It's Tuesday afternoon in your first week as ScribeUp's first DevOps hire. Our scan service (an API, a background worker, Postgres, an SQS queue and an S3 bucket) runs on AWS, and until now product engineers have handled the infrastructure on the side. `APP.md` describes what's running.

Acme Credit Union turns ScribeUp on for 40,000 members on **Thursday at 9am ET**. Jordan, one of our engineers, used an AI assistant to fix the findings from our security scanner and opened a [pull request](https://github.com/ScribeUp/scribeup-coding-challenge-2026-devops/pull/1). They want to apply it to production **tonight at 6pm**, and you're the reviewer.

## Setup (about 15 minutes)

You need Docker (with Compose v2) and git. Terraform and the AWS CLI run in Docker through `./tf` and `./aws`, so you don't need them installed.

```
make up          # "production": LocalStack plays AWS, prod/core is applied to it, plus the API, worker and traffic
make queue       # the scan queue is busy
make plan        # plans prod/core against production: no changes yet
make test        # app tests
make validate    # terraform fmt + validate for prod/core and prod/database (plus actionlint if installed)
```

To look at Jordan's change: `git checkout -b review origin/jl/checkov-fixes`, then `make plan`. The [pull request](https://github.com/ScribeUp/scribeup-coding-challenge-2026-devops/pull/1) has Jordan's description and the database plan they ran against the real account.

**No AWS account is needed; please don't use one.** `make down` resets everything.

## What to do

### 1. Review the PR (about 1 hour)

Decide what should happen to each change in it, and write it up in `REVIEW.md` (template provided). Then commit the version of the change you would approve for tonight, as a commit on top of Jordan's. Applying it to local production is optional.

We care about what each change would actually do to production, which isn't always what the diff or the plan says at first glance. `APP.md` has what you need.

### 2. Plan the rest (about 30 minutes)

Some changes shouldn't go out tonight. In `PLAN.md` (one page, template provided), say how you'd land them after the launch: order, expected downtime, how you'd roll back, and who needs to know.

### 3. Guard against it next time (about 30 minutes)

Write `scripts/plan_guard`: an executable (any language) that takes the path of a JSON plan (`terraform show -json`) and exits non-zero, with a reason, if applying that plan would destroy or replace anything that holds data. Someone who means to do it can set `ALLOW_DESTROY` to a comma-separated list of resource addresses. `make plan` runs it.

Then add `.github/workflows/terraform.yml`: plan on pull requests, run your guard, and apply `main` only with an approval. Assume the AWS credentials come from OIDC.

We'll run your guard against plans you haven't seen.

### 4. `AI_LOG.md` (10 minutes)

Which AI tools you used and for what, two or three places where the AI was wrong or you didn't trust it, and how you checked.

## Ground rules

- **Use AI tools** the way you normally would. We assume your AI can do a lot of this, so we grade the judgment you add on top: what you checked, what you changed, what you'd tell Jordan. In the follow-up you'll explain your calls yourself.
- If you run out of time, stop and write down what you'd do next.
- Commit as you go so we can see how you worked.

## The follow-up session (45 minutes)

A conversation about your review: a two-minute summary from you, then our follow-up questions on your calls.

## Submitting

Clone this repo and push your work to a new private repo of your own, then share it with us (or send a zip, including `.git`). Please don't use GitHub's Fork button: forks of a public repo are public, so other candidates could find your work.
