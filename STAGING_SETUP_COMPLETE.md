# Staging Environment Setup - Complete

## Status Summary

### ✅ Working Services

1. **n8n** - Fully operational
   - URL: http://localhost:5679
   - Username: admin
   - Password: changeme123
   - Status: Healthy
   - Database: Healthy (Postgres 15)

2. **Supabase Core Services**
   - Database (Postgres): Healthy (port 5433)
   - REST API (PostgREST): Working (http://localhost:8001/rest/v1/)
   - Auth Service: Running
   - Kong API Gateway: Healthy (http://localhost:8001)
   - Realtime: Running
   - Meta (Database Management): Healthy

###  ⚠️ Services with Minor Issues

1. **Supabase Studio** - UI accessible but unhealthy status
   - URL: http://localhost:3001
   - May have some functionality limitations

2. **Supabase Storage** - Restarting due to missing tables
   - The service needs storage tables to be created
   - This is a known issue with the initialization order

## Fixed Issues

1. ✅ Supabase database volume ownership (macOS Docker issue)
   - Solution: Changed from named volumes to bind mounts
   - Path: `docker/supabase/volumes/db/data`

2. ✅ Kong API Gateway configuration missing
   - Created: `docker/supabase/volumes/kong/kong.yml`

3. ✅ Database schemas and roles
   - Created initialization scripts in `docker/supabase/volumes/db/init/`
   - Manually applied: schemas (auth, storage, realtime, etc.) and roles (anon, authenticated, service_role)

## Configuration Files

- **Environment**: `environments/staging/.env`
- **State**: `environments/staging/state.json`
- **Docker Compose**: `docker-compose.yml` (modified for macOS compatibility)

## Important Changes Made

1. **docker-compose.yml**:
   - Removed `PGDATA` environment variable from supabase-db
   - Changed supabase-db volume from named volume to bind mount
   - Updated volume definitions

2. **Initialization Scripts** (in `docker/supabase/volumes/db/init/`):
   - `00-init-schemas.sql` - Creates Supabase schemas
   - `01-init-roles.sql` - Creates database roles

3. **Kong Configuration**:
   - `docker/supabase/volumes/kong/kong.yml` - API Gateway routes

## Usage

### Start the platform:
```bash
./platform.sh up staging
```

### Stop the platform:
```bash
./platform.sh down staging
```

### Check status:
```bash
./platform.sh status staging
```

### View logs:
```bash
./platform.sh logs staging [service-name]
```

## Testing the Services

### Test n8n:
```bash
curl http://localhost:5679/healthz
# Expected: {"status":"ok"}
```

### Test Supabase REST API:
```bash
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  http://localhost:8001/rest/v1/
# Expected: OpenAPI schema
```

### Access Supabase Studio:
Open http://localhost:3001 in your browser

## Known Limitations

1. **Storage Service**: Continues to restart due to missing storage tables. This won't affect basic Supabase functionality (auth, database, API) but file storage features won't work until resolved.

2. **Studio Health Check**: Shows as unhealthy but the UI is accessible and functional.

## Next Steps

To fully fix the storage service, you would need to:
1. Let the storage service create its tables on first run
2. Or manually create the storage schema tables based on Supabase storage migrations

## Ports

- n8n: **5679**
- n8n Postgres: 5432 (internal)
- Supabase Database: **5433**
- Supabase Kong (API): **8001**
- Supabase Kong HTTPS: **8443**
- Supabase Studio: **3001**

## Security Notes

**Default Credentials** (CHANGE IN PRODUCTION):
- n8n: admin / changeme123
- Supabase has demo JWT keys (ANON_KEY, SERVICE_ROLE_KEY)
- Database passwords are auto-generated in `.env` file

## Date Completed

2026-01-27
