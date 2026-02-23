# Terraform Deployment for Budget App

## Prerequisites
- Terraform installed (v1.0+)
- AWS CLI configured with credentials
- AWS account with appropriate permissions

## Deployment Steps

### 1. Configure Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `bucket_name`: Choose a globally unique S3 bucket name

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Review Plan
```bash
terraform plan
```

### 4. Deploy Infrastructure
```bash
terraform apply
```

Type `yes` when prompted.

### 5. Get Outputs
After deployment completes, note the outputs:
```bash
terraform output
```

You'll see:
- `api_gateway_url`: Your API endpoint
- `s3_website_url`: Your website URL
- `bucket_name`: Your S3 bucket name

### 6. Update config.js
Edit `../config.js` and replace `API_URL` with the `api_gateway_url` from outputs.

### 7. Upload Website Files
```bash
aws s3 sync ../ s3://YOUR-BUCKET-NAME/ --exclude "terraform/*" --exclude "lambda/*" --exclude ".git/*" --exclude "AWS_SETUP.txt"
```

Or upload these files manually:
- login.html
- register.html
- budgetmain.html
- overview.html
- details.html
- config.js

### 8. Access Your App
Open the `s3_website_url` in your browser.

## Cleanup
To destroy all resources:
```bash
terraform destroy
```

## What Gets Created
- 2 DynamoDB tables (BudgetData, Users)
- 1 Lambda function (BudgetAPI)
- 1 API Gateway REST API
- 1 S3 bucket (static website hosting)
- IAM roles and policies
- CloudWatch log groups

## Cost
All resources use free tier where available. Typical monthly cost: $0
