# Example CI output

Workflow: `.github/workflows/ci.yml`. The latest runs are on the repository's **Actions** tab.

Run link: <https://github.com/aryansharma2208/msd_assignment/actions/runs/40948219096>

## Run summary

All three jobs passed: app tests, Terraform validation, and the live check
against the deployed instance.

![CI run #2: all three jobs green](images/ci-run-summary.png)

## Log excerpts

Unit tests:

![Unit test log: four tests ok](images/ci-unit-tests.png)

Smoke test (service started in CI and checked with `scripts/verify.sh`):

![Smoke test log: all checks passed](images/ci-smoke-test.png)

Terraform init and validate:

![terraform validate: the configuration is valid](images/ci-terraform-validate.png)
