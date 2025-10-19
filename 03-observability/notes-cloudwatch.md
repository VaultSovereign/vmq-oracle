CloudWatch and Sync Observability

- Data source sync: use `aws qbusiness list-data-source-sync-jobs` with `--application-id`, `--index-id`, and `--data-source-id` to view state.
- CloudWatch Logs: enable connector logging (if supported) and query by log group in eu-west-1.
- Metrics to watch: sync success/failure counts, item counts processed, throttles, API errors.
- CloudTrail: audit calls to qbusiness and iam for role/passrole/assume-role actions.

Quick commands

```
aws qbusiness list-data-source-sync-jobs \
  --region eu-west-1 \
  --application-id "$APP_ID" \
  --index-id "$INDEX_ID" \
  --data-source-id "$DS_ID"
```

