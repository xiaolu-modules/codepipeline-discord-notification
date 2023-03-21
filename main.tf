# This HACK installs NPM packages on every run so we get lambda function ready to be published
resource "null_resource" "pull_and_install_github_repo" {
  triggers = {
    force_run = uuid()
  }
  provisioner "local-exec" {
    command = "cd ${path.module}/aws-codepipeline-discord-integration && npm install"
  }
}

# Zip up Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/aws-codepipeline-discord-integration"
  output_path = "${path.module}/tmp/aws-codepipeline-discord-integration.zip"

  depends_on = [null_resource.pull_and_install_github_repo]
}

# Role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-discord-integration-lambda-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM Policy for Lambda function
resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "${var.app_name}-discord-integration-lambda-role-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [{
      "Sid": "WriteLogsToCloudWatch",
      "Effect" : "Allow",
      "Action" : [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource" : "arn:aws:logs:*:*:*"
    }, {
      "Sid": "AllowAccesstoPipeline",
      "Effect" : "Allow",
      "Action" : [
        "codepipeline:GetPipeline",
        "codepipeline:GetPipelineState",
        "codepipeline:GetPipelineExecution",
        "codepipeline:ListPipelineExecutions",
        "codepipeline:ListActionTypes",
        "codepipeline:ListPipelines"
      ],
      "Resource" : ${jsonencode(formatlist("arn:aws:codepipeline:*:*:%s", var.pipeline_names))}
    }
  ]
}
EOF
}

resource "aws_lambda_function" "lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  description      = "Posts a message to Discord channel '${var.discord_channel}' every time there is an update to codepipeline execution."
  function_name    = "${var.app_name}-discord-integration-lambda-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.handle"
  runtime          = "nodejs12.x"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      "DISCORD_WEBHOOK_URL" = var.discord_webhook_url
      "DISCORD_CHANNEL"     = var.discord_channel
      "RELEVANT_STAGES"     = var.relavent_stages
      "REGION"              = var.region
      "BOT_NAME"            = var.bot_name
    }
  }
}

# Alias pointing to latest for Lambda function
resource "aws_lambda_alias" "lambda_alias" {
  name             = "latest"
  function_name    = aws_lambda_function.lambda.arn
  function_version = "$LATEST"
}

# Cloudwatch event rule
resource "aws_cloudwatch_event_rule" "pipeline_state_update" {
  name        = "${var.app_name}-discord-integration-pipeline-updated-${var.environment}"
  description = "Capture state changes in pipelines '${join(", ", var.pipeline_names)}'"

  event_pattern = <<PATTERN
{
  "detail": {
    "pipeline": ${jsonencode(var.pipeline_names)}
  },
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "source": [
    "aws.codepipeline"
  ]
}
PATTERN
}


# Allow Cloudwatch to invoke Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pipeline_state_update.arn
  qualifier     = aws_lambda_alias.lambda_alias.name
}

# Map event rule to trigger lambda function
resource "aws_cloudwatch_event_target" "lambda_trigger" {
  rule = aws_cloudwatch_event_rule.pipeline_state_update.name
  arn  = aws_lambda_alias.lambda_alias.arn
}
