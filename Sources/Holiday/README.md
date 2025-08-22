# Holiday - Toggle Between Static Pages and ECS Services

The Holiday tool allows you to quickly switch between serving static "we're on holiday" pages and running full ECS
services. This is useful for cost savings during holidays or maintenance periods.

## Prerequisites

- AWS credentials configured (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`)

- Access to manage ECS services, ALB rules, and S3 buckets

- Swift installed on your system

## Commands

### Enable Holiday Mode (Turn OFF ECS Services)

```bash
swift run Holiday vacation
```

This command will:

1. Upload static holiday pages to S3 bucket `sagebrush-public`
2. Update ALB listener rules to redirect to static S3 pages
3. Stop all ECS services (set desired count to 0)

### Enable Work Mode (Turn ON ECS Services)

```bash
swift run Holiday work
```

This command will:

1. Start all ECS services (set desired count to 1)
2. Wait for services to become healthy
3. Update ALB listener rules to forward to ECS target groups

## Affected Services and Domains

The following unified service and its associated domain is managed:

- **bazaar-service** → <www.sagebrush.services> (unified Bazaar service serving both web content and API)

Note: This is a streamlined configuration focusing on the unified Bazaar service. Other services (neon-web, nlf-web) are
currently commented out in the Holiday configuration and can be re-enabled when needed.

## Testing the Status

After running either command, you can verify the status using curl:

### Test Holiday Mode (Static Pages)

```bash
# Test www.sagebrush.services - should return HTTP 301 redirect to S3
curl -I https://www.sagebrush.services

# Follow redirects to see the actual content
curl -L https://www.sagebrush.services
```

Expected behavior in holiday mode:

- HTTP 301 redirect to S3 static page

- Location header pointing to: <https://sagebrush-public.s3.us-west-2.amazonaws.com:443/holiday/{domain}/index.html>

- Static HTML page explaining the trifecta and holiday status

- Contact email: `support@sagebrush.services`

### Test Work Mode (ECS Services)

```bash
# Test www.sagebrush.services - should return response from unified Bazaar ECS service
curl -I https://www.sagebrush.services

# Test API endpoints
curl -I https://www.sagebrush.services/api/legal-jurisdictions
curl -I https://www.sagebrush.services/health
```

Expected behavior in work mode:

- HTTP 200 responses from ECS services

- Dynamic content from each application

- Headers indicating response from ECS/ALB infrastructure

## Monitoring

### Check ECS Service Status

```bash
# Check if services are running (desired count > 0)
aws ecs describe-services \
  --cluster standards-cluster \
  --services standards-service \
  --region us-west-2 \
  --query 'services[0].desiredCount'

# Check unified Bazaar service
aws ecs describe-services \
  --cluster bazaar-cluster \
  --services bazaar \
  --region us-west-2 \
  --query 'services[0].desiredCount'
```

### Check S3 Holiday Pages

```bash
# List holiday pages in S3
aws s3 ls s3://sagebrush-public/holiday/ --recursive

# View a specific holiday page
aws s3 cp s3://sagebrush-public/holiday/www.sagebrush.services/index.html -
```

### Check ALB Listener Rules

```bash
# Get ALB listener rules (requires listener ARN)
aws elbv2 describe-rules \
  --listener-arn <LISTENER_ARN> \
  --region us-west-2 \
  --query 'Rules[?Priority==`200`].Actions[0].Type'
```

## Important Notes

1. **Cost Savings**: Running in holiday mode stops all ECS tasks, significantly reducing AWS costs
2. **Response Time**: After switching to work mode, allow 30-60 seconds for services to become healthy
3. **Authentication**: Some paths may require authentication even in holiday mode
4. **S3 Bucket**: The `sagebrush-public` bucket must exist and be publicly accessible
5. **Rollback**: If something goes wrong, you can always manually adjust ECS service counts and ALB rules

## Troubleshooting

### Services Not Starting

- Check ECS task definitions are valid

- Verify sufficient capacity in the cluster

- Check CloudWatch logs for task failures

### Static Pages Not Loading

- Verify S3 bucket permissions

- Check ALB listener rule modifications

- Ensure S3 bucket has public access enabled

### ALB Rules Not Updating

- Verify IAM permissions for modifying ALB rules

- Check listener rule priorities match expected values

- Ensure target groups exist for work mode

## Emergency Manual Override

If the Holiday tool fails, you can manually control services:

```bash
# Manually stop the unified Bazaar service
aws ecs update-service \
  --cluster bazaar-cluster \
  --service bazaar \
  --desired-count 0 \
  --region us-west-2

# Manually start the unified Bazaar service
aws ecs update-service \
  --cluster bazaar-cluster \
  --service bazaar \
  --desired-count 1 \
  --region us-west-2
```
