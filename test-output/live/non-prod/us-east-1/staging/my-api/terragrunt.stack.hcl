# Deployment stack for my-api in staging environment

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  service     = "my-api"

  catalog_path = "git::git@github.com:YOUR_ORG/infrastructure-catalog.git"
}

# Deploy the serverless-api stack from the catalog
unit "api" {
  source = "${local.catalog_path}//stacks/serverless-api?ref=main"
  path   = "api"

  values = {
    # Stack configuration
    service         = local.service
    environment     = local.environment
    catalog_version = "main"

    # Module versions
    s3_module_version       = "v1.0.0"
    dynamodb_module_version = "v1.0.0"
    lambda_module_version   = "v1.0.0"

    # Lambda configuration
    lambda_handler     = "src/handler.main"
    lambda_runtime     = "python3.12"
    lambda_memory_size = 512
    lambda_timeout     = 60
    lambda_s3_key      = "deployments/my-api/latest.zip"

    lambda_environment_variables = {
      LOG_LEVEL = "DEBUG"
      API_URL   = "https://api.staging.example.com"
    }

    # DynamoDB configuration
    dynamodb_hash_key  = "PK"
    dynamodb_range_key = "SK"
    dynamodb_attributes = [
      { name = "PK", type = "S" },
      { name = "SK", type = "S" },
      { name = "GSI1PK", type = "S" },
      { name = "GSI1SK", type = "S" }
    ]
    dynamodb_gsis = [
      {
        name            = "GSI1"
        hash_key        = "GSI1PK"
        range_key       = "GSI1SK"
        projection_type = "ALL"
      }
    ]

    # Tags
    tags = merge(local.account_vars.locals.tags, {
      Service = local.service
    })
  }
}
