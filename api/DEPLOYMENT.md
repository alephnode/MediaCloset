# MediaCloset API - Railway Deployment Guide

This guide explains how to deploy the MediaCloset GraphQL API to Railway.

## Prerequisites

1. A Railway account (https://railway.app)
2. Railway CLI installed (optional, for local testing)
3. Your environment variable values ready

## Deployment Steps

### 1. Create a New Railway Project

1. Go to https://railway.app/new
2. Click "Deploy from GitHub repo"
3. Select your MediaCloset repository
4. Railway will detect the Dockerfile and build automatically

### 2. Configure the Service

Railway should auto-detect the `api` directory. If not:

1. Go to Settings → Build & Deploy
2. Set Root Directory to `api`
3. Ensure Dockerfile path is correct: `Dockerfile`

### 3. Set Environment Variables

In Railway dashboard, go to Variables and add the following:

**Required Variables:**
```
API_KEY=<generate-a-secure-random-key>
ENVIRONMENT=production
HASURA_ENDPOINT=<your-hasura-graphql-endpoint>
HASURA_ADMIN_SECRET=<your-hasura-admin-secret>
OMDB_API_KEY=<your-omdb-api-key>
```

**Optional Variables:**
```
PORT=8080
DISCOGS_CONSUMER_KEY=<your-discogs-key>
DISCOGS_CONSUMER_SECRET=<your-discogs-secret>
LASTFM_API_KEY=<your-lastfm-key>
ENABLE_CACHE=false
ENABLE_RATE_LIMIT=true
```

**Generating a Secure API Key:**
```bash
# On macOS/Linux
openssl rand -base64 32

# Or use a password generator
# Example: "5f8a9b2c1d3e4f6g7h8i9j0k1l2m3n4o"
```

### 4. Deploy

1. Railway will automatically deploy after you push to your repository
2. Or click "Deploy" in the Railway dashboard
3. Monitor the build logs in the Railway dashboard

### 5. Get Your Production URL

1. In Railway dashboard, go to Settings → Domains
2. Click "Generate Domain" to get a `*.railway.app` URL
3. Optionally add a custom domain

Your API will be available at:
- GraphQL endpoint: `https://your-app.railway.app/query`
- Health check: `https://your-app.railway.app/health`

## Testing the Deployment

### Test Health Endpoint (No Auth)
```bash
curl https://your-app.railway.app/health
```

Expected response:
```json
{"status":"ok","version":"1.0.0","uptime":123}
```

### Test GraphQL Endpoint (With Auth)
```bash
curl -X POST https://your-app.railway.app/query \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key-here" \
  -d '{"query":"query{health{status}}"}'
```

Expected response:
```json
{"data":{"health":{"status":"ok"}}}
```

### Test Without API Key (Should Fail)
```bash
curl -X POST https://your-app.railway.app/query \
  -H "Content-Type: application/json" \
  -d '{"query":"query{health{status}}"}'
```

Expected response:
```json
{"error":"Missing X-API-Key header"}
```

## Updating iOS App for Production

Update your iOS app's configuration to use the production URL:

### In `ios/Configs/Local.secrets.xcconfig`:
```
MEDIACLOSET_API_ENDPOINT = https://your-app.railway.app/query
MEDIACLOSET_API_KEY = <your-production-api-key>
```

Or create a separate `Production.secrets.xcconfig` for production builds.

## Monitoring

Railway provides built-in monitoring:
- View logs in the Railway dashboard
- Monitor resource usage (CPU, Memory, Network)
- Set up alerts for downtime

## Troubleshooting

### Build Fails
- Check the build logs in Railway dashboard
- Ensure Dockerfile is in the `api` directory
- Verify all dependencies are in go.mod

### Server Crashes on Startup
- Check environment variables are set correctly
- Verify API_KEY, HASURA_ENDPOINT, and HASURA_ADMIN_SECRET are present
- Check the logs for specific error messages

### API Returns 401 Unauthorized
- Verify you're sending the X-API-Key header
- Confirm the API key matches the one in Railway environment variables
- Check the API key doesn't have extra spaces or newlines

### API Returns 429 Rate Limit Exceeded
- You're exceeding 100 requests/minute
- Wait for the rate limit to reset
- Consider increasing the rate limit in `internal/middleware/ratelimit.go`

## Rollback

If you need to rollback to a previous version:

1. Go to Deployments in Railway dashboard
2. Find the working deployment
3. Click "Redeploy"

## Local Testing with Docker

Before deploying, test the Docker build locally:

```bash
# Build the image
docker build -t mediacloset-api .

# Run the container
docker run -p 8080:8080 \
  -e API_KEY=test-key \
  -e ENVIRONMENT=development \
  -e HASURA_ENDPOINT=your-hasura-url \
  -e HASURA_ADMIN_SECRET=your-secret \
  -e OMDB_API_KEY=your-omdb-key \
  mediacloset-api

# Test
curl http://localhost:8080/health
```

## Security Checklist

Before deploying to production:

- ✅ Generate a strong, unique API_KEY
- ✅ Use HTTPS only (Railway provides this automatically)
- ✅ Verify rate limiting is enabled (ENABLE_RATE_LIMIT=true)
- ✅ Keep HASURA_ADMIN_SECRET secure and don't share it
- ✅ Regularly rotate API keys
- ✅ Monitor logs for suspicious activity

## Support

For Railway-specific issues:
- Railway Documentation: https://docs.railway.app
- Railway Discord: https://discord.gg/railway

For MediaCloset API issues:
- Check the logs in Railway dashboard
- Review the code in the repository
- Ensure all environment variables are set correctly
