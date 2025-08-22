# Update Services

## Usage

```txt
/update-services
```

Restart all available AWS ECS services in us-west-2 with the following steps:

1. List all ECS clusters: `aws ecs list-clusters --region us-west-2`
2. For each cluster, list services:
   `aws ecs list-services --cluster <cluster-name> --region us-west-2`
3. For each service, force a new deployment:
   `aws ecs update-service --cluster <cluster-name> --service <service-name>
   --force-new-deployment --region us-west-2`
4. Wait for services to stabilize:
   `aws ecs wait services-stable --cluster <cluster-name> --services <service-name>
   --region us-west-2`
