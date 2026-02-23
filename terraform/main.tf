terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket       = "evamerica0442-terraform-state-bucket-001"
    key          = "budgetapp/terraform.tfstate" # path inside bucket
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# DynamoDB Tables
resource "aws_dynamodb_table" "budget_data" {
  name         = "BudgetData"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "yearMonth"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "yearMonth"
    type = "S"
  }

  tags = {
    Name = "BudgetData"
  }
}

resource "aws_dynamodb_table" "users" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"

  attribute {
    name = "username"
    type = "S"
  }

  tags = {
    Name = "Users"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "budget_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.budget_data.arn,
          aws_dynamodb_table.users.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/budgetApi.mjs"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "budget_api" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "BudgetAPI"
  role             = aws_iam_role.lambda_role.arn
  handler          = "budgetApi.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 30

  environment {
    variables = {
      BUDGET_TABLE = aws_dynamodb_table.budget_data.name
      USERS_TABLE  = aws_dynamodb_table.users.name
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "budget_api" {
  name = "BudgetAPI"
}

resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  parent_id   = aws_api_gateway_rest_api.budget_api.root_resource_id
  path_part   = "register"
}

resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  parent_id   = aws_api_gateway_rest_api.budget_api.root_resource_id
  path_part   = "login"
}

resource "aws_api_gateway_resource" "budget" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  parent_id   = aws_api_gateway_rest_api.budget_api.root_resource_id
  path_part   = "budget"
}

resource "aws_api_gateway_resource" "budget_user" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  parent_id   = aws_api_gateway_resource.budget.id
  path_part   = "{userId}"
}

resource "aws_api_gateway_resource" "budget_month" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  parent_id   = aws_api_gateway_resource.budget_user.id
  path_part   = "{yearMonth}"
}

# Methods
resource "aws_api_gateway_method" "register_post" {
  rest_api_id   = aws_api_gateway_rest_api.budget_api.id
  resource_id   = aws_api_gateway_resource.register.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "register_post_200" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.register.id
  http_method = aws_api_gateway_method.register_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "login_post" {
  rest_api_id   = aws_api_gateway_rest_api.budget_api.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "login_post_200" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "budget_post" {
  rest_api_id   = aws_api_gateway_rest_api.budget_api.id
  resource_id   = aws_api_gateway_resource.budget.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "budget_post_200" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.budget.id
  http_method = aws_api_gateway_method.budget_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "budget_get" {
  rest_api_id   = aws_api_gateway_rest_api.budget_api.id
  resource_id   = aws_api_gateway_resource.budget_month.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "budget_get_200" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.budget_month.id
  http_method = aws_api_gateway_method.budget_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Integrations
resource "aws_api_gateway_integration" "register_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.budget_api.id
  resource_id             = aws_api_gateway_resource.register.id
  http_method             = aws_api_gateway_method.register_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.budget_api.invoke_arn
}

resource "aws_api_gateway_integration_response" "register_lambda" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.register.id
  http_method = aws_api_gateway_method.register_post.http_method
  status_code = aws_api_gateway_method_response.register_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.register_lambda]
}

resource "aws_api_gateway_integration" "login_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.budget_api.id
  resource_id             = aws_api_gateway_resource.login.id
  http_method             = aws_api_gateway_method.login_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.budget_api.invoke_arn
}

resource "aws_api_gateway_integration_response" "login_lambda" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_post.http_method
  status_code = aws_api_gateway_method_response.login_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.login_lambda]
}

resource "aws_api_gateway_integration" "budget_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.budget_api.id
  resource_id             = aws_api_gateway_resource.budget.id
  http_method             = aws_api_gateway_method.budget_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.budget_api.invoke_arn
}

resource "aws_api_gateway_integration_response" "budget_post_lambda" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.budget.id
  http_method = aws_api_gateway_method.budget_post.http_method
  status_code = aws_api_gateway_method_response.budget_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.budget_post_lambda]
}

resource "aws_api_gateway_integration" "budget_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.budget_api.id
  resource_id             = aws_api_gateway_resource.budget_month.id
  http_method             = aws_api_gateway_method.budget_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.budget_api.invoke_arn
}

resource "aws_api_gateway_integration_response" "budget_get_lambda" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id
  resource_id = aws_api_gateway_resource.budget_month.id
  http_method = aws_api_gateway_method.budget_get.http_method
  status_code = aws_api_gateway_method_response.budget_get_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.budget_get_lambda]
}

# Lambda Permissions
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.budget_api.execution_arn}/*/*"
}

# CORS
module "cors_register" {
  source          = "./modules/cors"
  api_id          = aws_api_gateway_rest_api.budget_api.id
  api_resource_id = aws_api_gateway_resource.register.id
}

module "cors_login" {
  source          = "./modules/cors"
  api_id          = aws_api_gateway_rest_api.budget_api.id
  api_resource_id = aws_api_gateway_resource.login.id
}

module "cors_budget" {
  source          = "./modules/cors"
  api_id          = aws_api_gateway_rest_api.budget_api.id
  api_resource_id = aws_api_gateway_resource.budget.id
}

module "cors_budget_month" {
  source          = "./modules/cors"
  api_id          = aws_api_gateway_rest_api.budget_api.id
  api_resource_id = aws_api_gateway_resource.budget_month.id
}

# Deployment
resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.budget_api.id

  depends_on = [
    aws_api_gateway_integration.register_lambda,
    aws_api_gateway_integration.login_lambda,
    aws_api_gateway_integration.budget_post_lambda,
    aws_api_gateway_integration.budget_get_lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id   = aws_api_gateway_rest_api.budget_api.id
  stage_name    = "prod"
}

# S3 Bucket for Static Website
resource "aws_s3_bucket" "budget_website" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "budget_website" {
  bucket = aws_s3_bucket.budget_website.id

  index_document {
    suffix = "login.html"
  }

  error_document {
    key = "login.html"
  }
}

resource "aws_s3_bucket_public_access_block" "budget_website" {
  bucket = aws_s3_bucket.budget_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "budget_website" {
  bucket = aws_s3_bucket.budget_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.budget_website.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.budget_website]
}
