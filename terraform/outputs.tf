output "api_gateway_url" {
  description = "API Gateway URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "s3_website_url" {
  description = "S3 Website URL"
  value       = "http://${aws_s3_bucket_website_configuration.budget_website.website_endpoint}"
}

output "bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.budget_website.id
}
