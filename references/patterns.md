# Terragrunt Patterns Guide

## Repository Separation Pattern

### Modules in Separate Repos (Recommended)

Consider maintaining modules in **separate Git repositories** rather than in the catalog:

```
# Module repos (separate per module)
github.com/YOUR_ORG/modules/rds.git
github.com/YOUR_ORG/modules/eks.git
github.com/YOUR_ORG/modules/dynamodb.git

# Catalog repo (units and stacks only)
github.com/YOUR_ORG/infrastructure-catalog.git
  └── units/
  └── stacks/

# Live repos (deployments)
github.com/YOUR_ORG/infrastructure-prod.git
github.com/YOUR_ORG/infrastructure-platform.git
```

**Trade-off:** Requires more initial development effort to set up, but each module gets a proper development workflow.

**Benefits:**
- Independent semantic versioning per module
- Dedicated CI/CD pipeline with automated testing (Terratest)
- Pre-commit hooks for formatting, validation, and security scanning
- Auto-generated documentation (terraform-docs)
- Clear team ownership boundaries
- Isolated blast radius for changes
- Explicit dependency management via version refs

**Pre-commit Hooks for Modules:**

Each module repo can have dedicated quality gates:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.81.0
    hooks:
      - id: terraform_fmt
        args:
          - --args=-no-color
          - --args=-diff
          - --args=-write=true
      - id: terraform_validate
        args:
          - --args=-json
          - --args=-no-color
  - repo: https://github.com/bridgecrewio/checkov.git
    rev: 2.3.334
    hooks:
      - id: checkov
        files: \.tf$
  - repo: https://github.com/terraform-docs/terraform-docs
    rev: "v0.16.0"
    hooks:
      - id: terraform-docs-go
        args: ["markdown", "--output-file", "../README.md", "./app"]
```

**Semantic Versioning with semantic-release:**

Automate module releases with conventional commits:

```yaml
# .releaserc.yml
ci: true
branches:
  - main
  - master
verifyConditions:
  - "@semantic-release/changelog"
  - "@semantic-release/git"
  - "@semantic-release/gitlab"  # or @semantic-release/github
analyzeCommits:
  - path: "@semantic-release/commit-analyzer"
prepare:
  - path: "@semantic-release/changelog"
    changelogFile: app/CHANGELOG.md
  - path: "@semantic-release/git"
    message: "RELEASE: ${nextRelease.version}"
    assets: ["app/CHANGELOG.md"]
publish:
  - "@semantic-release/gitlab"  # or @semantic-release/github
success: false
fail: false
npmPublish: false
```

This enables:
- Automatic version bumps based on commit messages (`feat:`, `fix:`, `BREAKING CHANGE:`)
- Auto-generated changelogs
- Git tags for each release (e.g., `v1.2.0`)
- Units reference specific versions: `?ref=v1.2.0`

### Unit Source Pattern

Units reference external module repos via Git URL:

```hcl
terraform {
  source = "git::git@github.com:YOUR_ORG/modules/rds.git//app?ref=${values.version}"
}
```

Key points:
- `//app` - Path within the module repo
- `?ref=${values.version}` - Version comes from stack's values

## Values Pattern

Units receive ALL configuration through the `values` object:

```hcl
# In unit terragrunt.hcl
inputs = {
  # Required - must be provided
  name = values.name

  # Optional - provide defaults with try()
  size = try(values.size, "medium")

  # Auto-detect from config presence
  create_feature = try(values.create_feature, length(try(values.feature_config, {})) > 0)
}
```

Stacks pass values to units:

```hcl
# In terragrunt.stack.hcl
unit "service" {
  source = "git::...//units/service?ref=main"
  path   = "service"
  values = {
    version = "v1.0.0"
    name    = "my-service"
    size    = "large"
  }
}
```

## Reference Resolution Pattern

Units resolve symbolic references like `"../acm"` to actual dependency outputs:

```hcl
# Stack provides simple reference
unit "cloudfront" {
  values = {
    acm_certificate_arn = "../acm"
  }
}

# Unit resolves to actual ARN
dependency "acm" {
  config_path = try(values.acm_path, "../acm")
  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  acm_certificate_arn = try(values.acm_certificate_arn, "") == "../acm" ?
    dependency.acm.outputs.acm_certificate_arn :
    values.acm_certificate_arn
}
```

Common references: `"../acm"`, `"../s3"`, `"../vpc"`, `"../cloudfront"`

## Dependency Path Override Pattern

Always allow path overrides for flexible composition:

```hcl
dependency "vpc" {
  config_path  = try(values.vpc_path, "../vpc")  # Override or default
  skip_outputs = !try(values.use_vpc, false)     # Conditional

  mock_outputs = {
    vpc_id = "vpc-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

## Optional Dependencies Pattern

Use `skip_outputs` or `enabled` for conditional dependencies:

```hcl
dependency "s3" {
  enabled      = try(values.use_s3_origin, false)
  config_path  = try(values.s3_path, "../s3")
  mock_outputs = { bucket_domain_name = "mock.s3.amazonaws.com" }
}

# Or with skip_outputs
dependency "acm" {
  config_path  = try(values.acm_path, "../acm")
  skip_outputs = !try(values.use_acm_certificate, false)
  mock_outputs = { acm_certificate_arn = "arn:aws:acm:..." }
}
```

## Cross-Account Provider Pattern

For resources in different accounts (e.g., Route53 in DNS account):

```hcl
# In unit
locals {
  use_dns_provider = try(values.dns_account_id, null) != null
  dns_account_id   = try(values.dns_account_id, "")
}

generate "provider_dns_override" {
  path      = "provider_dns_override.tf"
  if_exists = "overwrite_terragrunt"
  # IMPORTANT: Wrap heredoc in parentheses for ternary
  contents  = local.use_dns_provider ? (
<<-EOF
provider "aws" {
  alias  = "dns"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.dns_account_id}:role/TerraformCrossAccount"
  }
}
EOF
  ) : ""
}
```

## Environment State Isolation

Each environment gets its own state bucket via `state_bucket_suffix`:

```hcl
# env.hcl
locals {
  environment         = "staging"
  state_bucket_suffix = local.environment
}
```

Results in:
- `tfstate-myproject-nonprod-staging-us-east-1`
- `tfstate-locks-myproject-nonprod-staging-us-east-1`

## Git URL Syntax

**CRITICAL: The refspec goes AFTER the double slash, not before**

```hcl
# CORRECT
source = "git::git@github.com:org/repo.git//units/acm?ref=main"

# WRONG - will cause "git refspec" error
source = "git::git@github.com:org/repo.git?ref=main//units/acm"
```

## Two Version Pattern

Stacks manage two different versions:

1. **Catalog ref** - Git branch/tag for the catalog (in source URL)
2. **Module version** - Git branch/tag for the underlying module (passed via values)

```hcl
unit "rds" {
  # Catalog version - where to get the unit from
  source = "git::...//units/rds?ref=main"

  values = {
    # Module version - what version of the RDS module to use
    version = "v3.0.1"
  }
}
```

## Auto-Detection Pattern

Auto-detect features from configuration presence:

```hcl
inputs = {
  # If feature_config is provided and non-empty, create the feature
  create_feature = try(values.create_feature, length(keys(try(values.feature_config, {}))) > 0)

  # Check if any record uses a reference
  use_cloudfront = try(
    anytrue([
      for record in try(values.records, []) :
        try(record.alias.name == "../cloudfront", false)
    ]),
    false
  )
}
```

## Common Pitfalls

1. **Git refspec error:** Use `//path?ref=branch` NOT `?ref=branch//path`
2. **Heredoc in ternary:** Wrap in parentheses: `condition ? (\n<<-EOF\n...\nEOF\n) : ""`
3. **Duplicate dependencies:** Each dependency block should appear only once
4. **Missing mock outputs:** Always provide for plan/validate commands
5. **Hardcoded local paths:** Use local paths only for testing, never in committed code
