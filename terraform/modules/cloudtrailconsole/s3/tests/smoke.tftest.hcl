mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  name = "cloudTrailConsole"

  s3 = {
    name = "example-cloudtrail-bucket"
  }

  # Point the lambda at a committed fixture; the default
  # ${path.module}/../../../../dist/function.zip is a build artifact
  # that does not exist in a fresh checkout.
  lambda = {
    filepath = "./tests/fixtures/function.zip"
  }
}

run "defaults" {
  command = apply

  assert {
    condition     = aws_lambda_function.default.function_name == "cloudTrailConsole"
    error_message = "Lambda function name should default to the module name"
  }

  assert {
    condition     = aws_lambda_function.default.handler == "main" && aws_lambda_function.default.runtime == "provided.al2023"
    error_message = "Lambda should default to handler=main on provided.al2023"
  }

  assert {
    condition     = aws_lambda_function.default.memory_size == 128 && aws_lambda_function.default.timeout == 15
    error_message = "Lambda should default to 128MB memory and 15s timeout"
  }

  assert {
    condition     = aws_lambda_function.default.reserved_concurrent_executions == 10
    error_message = "Lambda should default to 10 reserved concurrent executions"
  }

  assert {
    condition     = aws_lambda_function.default.architectures == tolist(["arm64"])
    error_message = "Lambda should default to arm64"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.default) == 0
    error_message = "Log group should not be created unless explicitly defined."
  }

  assert {
    condition     = aws_s3_bucket_notification.default.bucket == "example-cloudtrail-bucket"
    error_message = "Bucket notification should target the provided bucket"
  }

  assert {
    condition     = aws_lambda_permission.default.principal == "s3.amazonaws.com"
    error_message = "Lambda permission should allow invocation from S3"
  }

  assert {
    condition     = aws_lambda_permission.default.source_arn == "arn:aws:s3:::example-cloudtrail-bucket"
    error_message = "Lambda permission source ARN should be the provided bucket"
  }

  assert {
    condition     = output.aws_caller_identity.account_id == "123456789012"
    error_message = "Caller identity output should pass through the mocked account id"
  }
}
run "create_log_group" {
  command = apply

  variables {
    logs = {
      create = true
    }
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.default[0]) > 0
    error_message = "Log group should be created when explicitly set"
  }
}

run "custom_logs" {
  command = apply

  variables {
    logs = {
      create            = true
      retention_in_days = 90
      skip_destroy      = true
      log_group_class   = "INFREQUENT_ACCESS"
      kms_key_id        = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.default[0].name == "/aws/lambda/cloudTrailConsole"
    error_message = "Log group should use the provided name"
  }

  assert {
    condition     = aws_cloudwatch_log_group.default[0].retention_in_days == 90
    error_message = "Log group should use the provided retention"
  }

  assert {
    condition     = aws_cloudwatch_log_group.default[0].skip_destroy == true
    error_message = "Log group should use the provided skip_destroy"
  }

  assert {
    condition     = aws_cloudwatch_log_group.default[0].log_group_class == "INFREQUENT_ACCESS"
    error_message = "Log group should use the provided log group class"
  }

  assert {
    condition     = aws_cloudwatch_log_group.default[0].kms_key_id == "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "Log group should use the provided KMS key"
  }
}

run "custom_name_and_tags" {
  command = apply

  variables {
    name = "myConsoleLogger"
    logs = {
      create = true
    }
    tags = {
      Environment = "non-prd"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_lambda_function.default.function_name == "myConsoleLogger"
    error_message = "Lambda should use the provided name"
  }

  assert {
    condition     = aws_iam_role.default.name == "myConsoleLogger"
    error_message = "IAM role should use the provided name"
  }

  assert {
    condition     = aws_cloudwatch_log_group.default[0].name == "/aws/lambda/myConsoleLogger"
    error_message = "Log group name should follow the provided name"
  }

  assert {
    condition     = aws_lambda_function.default.tags["Environment"] == "non-prd" && aws_lambda_function.default.tags["Name"] == "myConsoleLogger"
    error_message = "Lambda tags should merge provided tags with the Name tag"
  }
}

run "lambda_overrides" {
  command = apply

  variables {
    lambda = {
      filepath                       = "./tests/fixtures/function.zip"
      memory                         = 256
      timeout                        = 60
      reserved_concurrent_executions = 5
      environment_variables = {
        LOG_LEVEL = "DEBUG"
      }
    }
  }

  assert {
    condition     = aws_lambda_function.default.memory_size == 256 && aws_lambda_function.default.timeout == 60
    error_message = "Lambda should use the provided memory and timeout"
  }

  assert {
    condition     = aws_lambda_function.default.reserved_concurrent_executions == 5
    error_message = "Lambda should use the provided reserved concurrency"
  }

  assert {
    condition     = aws_lambda_function.default.environment[0].variables["LOG_LEVEL"] == "DEBUG"
    error_message = "Lambda should include the provided environment variables"
  }
}

run "slack_settings" {
  command = apply

  variables {
    slack = {
      name    = ":maple_leaf: NON-PRD"
      channel = "#cloudtrail-console-actions"
      webhook = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
      accounts = {
        "123456789012" = ":maple_leaf: NON-PRD"
        "210987654321" = ":evergreen_tree: PRD"
      }
    }
  }

  assert {
    condition     = aws_lambda_function.default.environment[0].variables["SLACK_NAME"] == ":maple_leaf: NON-PRD"
    error_message = "Lambda environment should include SLACK_NAME"
  }

  assert {
    condition     = aws_lambda_function.default.environment[0].variables["SLACK_CHANNEL"] == "#cloudtrail-console-actions"
    error_message = "Lambda environment should include SLACK_CHANNEL"
  }

  assert {
    condition     = aws_lambda_function.default.environment[0].variables["SLACK_WEBHOOK"] == "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
    error_message = "Lambda environment should include SLACK_WEBHOOK"
  }

  assert {
    condition     = aws_lambda_function.default.environment[0].variables["SLACK_NAME_123456789012"] == ":maple_leaf: NON-PRD"
    error_message = "Lambda environment should include per-account SLACK_NAME_<account_id>"
  }

  assert {
    condition     = aws_lambda_function.default.environment[0].variables["SLACK_NAME_210987654321"] == ":evergreen_tree: PRD"
    error_message = "Lambda environment should include per-account SLACK_NAME_<account_id>"
  }
}
