# Update Infrastructure

## Usage

```txt
/update-infrastructure
```

Run `swift run Vegas infrastructure` to update AWS CloudFormation stacks. Follow
these steps:

1. Run `swift run Vegas infrastructure` to attempt stack updates
2. Check all CloudFormation stacks for completion status:

   ```bash
   aws cloudformation list-stacks \
     --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_IN_PROGRESS \
                           CREATE_IN_PROGRESS \
     --region us-west-2 \
     --query 'StackSummaries[*].[StackName,StackStatus]' \
     --output table
   ```

3. Verify no stacks are still in progress:

   ```bash
   aws cloudformation list-stacks \
     --stack-status-filter UPDATE_IN_PROGRESS CREATE_IN_PROGRESS \
     --region us-west-2 \
     --query 'StackSummaries[*].[StackName,StackStatus]' \
     --output table
   ```

4. If any SQS queues conflict (already exist outside CloudFormation), delete them
   with `aws sqs delete-queue`
5. Handle stack rollback states:
   - If a stack is in `ROLLBACK_COMPLETE` state (failed initial creation), delete it
     with
     `aws cloudformation delete-stack`
   - If a stack is in `UPDATE_ROLLBACK_COMPLETE` state (was previously created
     successfully), keep updating it
     with `swift run Vegas infrastructure`
   - NEVER delete stacks that have been successfully created (CREATE_COMPLETE or
     UPDATE_COMPLETE history)
6. Wait for all operations to complete and verify all stacks are CREATE_COMPLETE or
   UPDATE_COMPLETE using the
   AWS CLI commands above
7. Re-run `swift run Vegas infrastructure` after clearing conflicts to recreate
   deleted stacks
