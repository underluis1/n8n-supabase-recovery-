# N8N Workflows

This directory will contain your project's n8n workflows.

## Export Workflows

```bash
# Method 1: Use sync script (recommended)
./scripts/sync-from-dev-cloud.sh

# Method 2: Via n8n API
curl -H "X-N8N-API-KEY: key" \
  https://your-n8n.app.n8n.cloud/api/v1/workflows/1 \
  > migrations/n8n/workflows/001_my_workflow.json
```

See parent README.md for workflow management.
