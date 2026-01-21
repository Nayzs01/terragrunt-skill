# Terragrunt Skill for Claude Code

A Claude Code skill providing best practices guidance for Terragrunt infrastructure-as-code with OpenTofu/Terraform.

## Features

### Catalog & Live Pattern
- **Infrastructure Catalog**: Reusable units and template stacks
- **Infrastructure Live**: Environment-specific deployments
- **Module Repos**: Separate repositories with semantic versioning

### Unit & Stack Patterns
- Values pattern for configuration injection
- Reference resolution (`"../unit"` → dependency outputs)
- Unit interdependencies with mock outputs
- Conditional dependencies with `enabled` and `skip_outputs`

### CI/CD Pipelines
- GitLab CI with reusable templates
- GitHub Actions workflows
- AWS OIDC authentication (`assume-role-with-web-identity`)
- GCP Workload Identity Federation
- SSH-based Git access (recommended over HTTPS)

### Performance Optimization
- Provider caching (`--provider-cache`)
- Two-layer caching architecture (local + network mirror)
- Benchmarking tools (Hyperfine, boring-registry)
- Explicit stacks for 2x faster runs

### Multi-Account Deployments
- Cross-account role assumption
- Environment-based state bucket separation
- Hierarchical configuration (root.hcl → account.hcl → region.hcl → env.hcl)

## Installation

### Claude Code Marketplace
```bash
/install jfr992/terragrunt-skill
```

> **Note:** Auto-discovery on claudemarketplaces.com requires 5+ GitHub stars. Before that threshold, use manual installation or share the direct repository link.

### Manual Installation
Clone to your Claude Code skills directory:
```bash
git clone https://github.com/jfr992/terragrunt-skill.git ~/.claude/skills/terragrunt-skill
```

### Local Testing
To test the skill in a specific project, add it to your project's Claude Code settings:

```bash
# Create .claude/settings.json in your project root
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "skills": ["~/.claude/skills/terragrunt-skill"]
}
EOF
```

Or add the skill path to your global Claude Code configuration.

## Usage

The skill activates when working with:
- `terragrunt.hcl` files (units)
- `terragrunt.stack.hcl` files (stacks)
- `root.hcl` configuration
- Terragrunt CLI commands

### Example Prompts
- "Create a new EKS stack with Karpenter and ArgoCD registration"
- "Set up a serverless API with Lambda, DynamoDB, and S3"
- "Add GitLab CI pipeline with GCP Workload Identity"
- "Optimize Terragrunt performance with provider caching"

## Documentation Structure

| File | Description |
|------|-------------|
| `SKILL.md` | Core skill documentation (~900 lines) |
| `references/cicd-pipelines.md` | GitLab CI & GitHub Actions templates |
| `references/patterns.md` | Repository separation, pre-commit, semantic-release |
| `references/performance.md` | Caching, benchmarking, optimization |
| `references/state-management.md` | S3/DynamoDB backend patterns |
| `references/multi-account.md` | Cross-account deployment patterns |

## Compatibility

- Terragrunt 0.68+
- OpenTofu 1.6+ / Terraform 1.5+
- AWS, GCP (authentication patterns)

## Contributing

See [CLAUDE.md](CLAUDE.md) for contributor guidelines and repository architecture.

## References

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terragrunt Stacks](https://terragrunt.gruntwork.io/docs/rfc/stacks/)
- [Terragrunt Cache Benchmark](https://github.com/jfr992/terragrunt-cache-test)
- [OpenTofu Documentation](https://opentofu.org/docs/)

## License

Apache 2.0
