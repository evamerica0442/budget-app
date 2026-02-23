BUDGET APP - DEPLOYMENT GUIDE
==============================

This is a serverless 3-tier budget tracking application deployed on AWS.

## Architecture Overview

See architecture-diagram.html for visual representation.

**Tier 1 - Presentation Layer:**
- Amazon S3: Static website hosting (HTML/CSS/JavaScript)
- CloudFront (Optional): CDN for global distribution

**Tier 2 - Application Layer:**
- API Gateway: REST API endpoints
- AWS Lambda: Serverless business logic (Node.js 20.x)

**Tier 3 - Data Layer:**
- DynamoDB: NoSQL database (Users & BudgetData tables)

## Prerequisites

- AWS Account with appropriate permissions
- Terraform installed (v1.0+)
- AWS CLI configured with credentials

## Deployment Options

### Option 1: Terraform (Recommended)

**Step 1: Configure Variables**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region  = "us-east-1"  # or your preferred region
bucket_name = "my-budget-app-unique-name"  # Must be globally unique
```
***NB..!!!!*** Before you Initialize Terraform please Study ****TERRAFORM_STATE.md*****

**Step 2: Initialize Terraform**
```bash
terraform init
```

**Step 3: Review Plan**
```bash
terraform plan
```

**Step 4: Deploy Infrastructure**
```bash
terraform apply
```
Type `yes` when prompted.

**Step 5: Get Outputs**
```bash
terraform output
```

Note the following outputs:
- `api_gateway_url`: Your API endpoint
- `s3_website_url`: Your website URL
- `bucket_name`: Your S3 bucket name

**Step 6: Update config.js**

Edit `config.js` and replace API_URL:
```javascript
const CONFIG = {
    API_URL: 'https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com/prod'
};
```

**Step 7: Upload Website Files**
```bash
aws s3 sync ../ s3://YOUR-BUCKET-NAME/ \
  --exclude "terraform/*" \
  --exclude "lambda/*" \
  --exclude ".git/*" \
  --exclude "*.txt" \
  --exclude "architecture-diagram.html"
```

Or upload these files manually:
- login.html
- register.html
- budgetmain.html
- overview.html
- details.html
- config.js

**Step 8: Access Your App**

Open the `s3_website_url` in your browser.

**Cleanup (Optional)**
```bash
terraform destroy
```

---

### Option 2: Manual AWS Console Setup

**Step 1: Create DynamoDB Tables**

A. BudgetData Table:
1. Go to AWS Console > DynamoDB
2. Click "Create table"
3. Table name: BudgetData
4. Partition key: userId (String)
5. Sort key: yearMonth (String)
6. Click "Create table"

B. Users Table:
1. Click "Create table"
2. Table name: Users
3. Partition key: username (String)
4. Click "Create table"

**Step 2: Create Lambda Function**
1. Go to AWS Console > Lambda
2. Click "Create function"
3. Function name: BudgetAPI
4. Runtime: Node.js 20.x
5. Click "Create function"
6. Copy code from lambda/budgetApi.mjs into the function
7. Handler: budgetApi.handler
8. Go to Configuration > Permissions
9. Add DynamoDB permissions to the execution role:
   - AmazonDynamoDBFullAccess (or create custom policy)

**Step 3: Create API Gateway**
1. Go to AWS Console > API Gateway
2. Click "Create API" > REST API
3. API name: BudgetAPI
4. Click "Create API"
5. Create resources and methods:
   - Create resource: /register
   - Add method: POST (integrate with Lambda)
   - Create resource: /login
   - Add method: POST (integrate with Lambda)
   - Create resource: /budget
   - Add method: POST (integrate with Lambda)
   - Create resource: /budget/{userId}/{yearMonth}
   - Add method: GET (integrate with Lambda)
6. Enable CORS for all methods:
   - Select each resource
   - Actions > Enable CORS
   - Enable CORS and replace existing CORS headers
7. Deploy API:
   - Actions > Deploy API
   - Stage name: prod
   - Copy the Invoke URL

**Step 4: Update config.js**

Replace API_URL with your API Gateway Invoke URL

**Step 5: Create S3 Bucket**
1. Create S3 bucket
2. Enable static website hosting
3. Index document: login.html
4. Upload all HTML files and config.js
5. Make bucket public or use CloudFront

**Step 6: Test**
1. Access your S3 website URL
2. Register a new user
3. Login with credentials
4. Add budget entries

---

## What Gets Created

- 2 DynamoDB tables (BudgetData, Users)
- 1 Lambda function (BudgetAPI)
- 1 API Gateway REST API
- 1 S3 bucket (static website hosting)
- IAM roles and policies
- CloudWatch log groups

## Cost Estimate (Free Tier)

- DynamoDB: 25 GB storage, 25 read/write units (FREE)
- Lambda: 1M requests/month (FREE)
- API Gateway: 1M requests/month (FREE for 12 months)
- S3: 5 GB storage, 20K GET requests (FREE for 12 months)

**Total: $0/month for typical personal use**

## Features

- Multi-tenant user authentication
- Monthly budget tracking (income & expenses)
- Edit and delete entries
- Monthly and yearly overview
- Detailed reports by category
- Export to text file
- Responsive dark theme UI

## Troubleshooting

**CORS Errors:**
- Enable CORS in API Gateway for all resources
- Redeploy API after changes

**Lambda Errors:**
- Check CloudWatch Logs for error details
- Verify DynamoDB table names match
- Ensure IAM role has DynamoDB permissions

**Registration/Login Fails:**
- Check browser console for errors
- Verify API Gateway URL in config.js
- Test Lambda function directly in console

## Security Notes

- Passwords are hashed with SHA-256
- For production, consider using AWS Cognito
- Enable HTTPS only (CloudFront + ACM certificate)
- Implement rate limiting in API Gateway
- Add input validation and sanitization

## Architecture Diagram

Open `architecture-diagram.html` in your browser to view the complete system architecture.

---

For questions or issues, check CloudWatch Logs in AWS Console.
