TERRAFORM REMOTE STATE CONFIGURATION
=====================================

## Overview

This project uses Terraform remote state stored in Amazon S3 for team collaboration,
state locking, and disaster recovery.

## Current Configuration

**Backend:** Amazon S3
**Bucket:** evamerica0442-terraform-state-bucket-001
**Key:** budgetapp/terraform.tfstate
**Region:** us-east-1
**Encryption:** Enabled
**Locking:** Enabled

## Setup Instructions

### 1. Create S3 Bucket for State (One-time setup)

```bash
aws s3 mb s3://evamerica0442-terraform-state-bucket-001 --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket evamerica0442-terraform-state-bucket-001 \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket evamerica0442-terraform-state-bucket-001 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. Initialize Terraform with Remote Backend

```bash
cd terraform
terraform init
```

This will:
- Download required providers
- Configure S3 backend
- Migrate local state to S3 (if exists)

### 3. Verify Remote State

```bash
terraform state list
```

## Benefits

✓ **Team Collaboration:** Multiple developers can work on infrastructure
✓ **State Locking:** Prevents concurrent modifications
✓ **Encryption:** State encrypted at rest
✓ **Versioning:** Rollback capability
✓ **Backup:** Automatic state backups
✓ **Audit Trail:** Track infrastructure changes

## State Operations

### View Current State
```bash
terraform state list
terraform state show <resource>
```

### Pull Remote State
```bash
terraform state pull > terraform.tfstate.backup
```

### Refresh State
```bash
terraform refresh
```

### Import Existing Resources
```bash
terraform import <resource_type>.<name> <resource_id>
```

## Security Best Practices

1. **Bucket Policy:** Restrict access to authorized users only
2. **Encryption:** Always enable encryption at rest
3. **Versioning:** Enable for state recovery
4. **Access Logs:** Enable S3 access logging
5. **MFA Delete:** Consider enabling for production

## Troubleshooting

### State Lock Error
If you get a state lock error:
```bash
terraform force-unlock <LOCK_ID>
```

### State Corruption
Restore from S3 version:
```bash
aws s3api list-object-versions \
  --bucket evamerica0442-terraform-state-bucket-001 \
  --prefix budgetapp/terraform.tfstate

aws s3api get-object \
  --bucket evamerica0442-terraform-state-bucket-001 \
  --key budgetapp/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.recovered
```

## Migration from Local State

If migrating from local state:

1. Backup local state:
```bash
cp terraform.tfstate terraform.tfstate.backup
```

2. Add backend configuration to main.tf

3. Initialize:
```bash
terraform init -migrate-state
```

4. Verify:
```bash
terraform state list
```

## Team Workflow

1. Pull latest changes: `git pull`
2. Initialize: `terraform init`
3. Plan changes: `terraform plan`
4. Apply changes: `terraform apply`
5. Commit code: `git commit && git push`

Note: State is automatically synced with S3, no manual push/pull needed.

## State File Structure

```
s3://evamerica0442-terraform-state-bucket-001/
└── budgetapp/
    └── terraform.tfstate
```

## Monitoring

Check state file in AWS Console:
- S3 Console > evamerica0442-terraform-state-bucket-001
- View versions, size, last modified
- Download for inspection (encrypted)

## Disaster Recovery

1. S3 versioning enabled - can restore previous versions
2. Regular backups via S3 lifecycle policies
3. Cross-region replication (optional for production)

---

For more information, see:
- Terraform S3 Backend: https://www.terraform.io/docs/language/settings/backends/s3.html
- AWS S3 Best Practices: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html
