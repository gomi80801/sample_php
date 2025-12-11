#!/bin/bash
set -e

# Deploy Memory Load Generator to Cloud Run
# Usage: ./deploy-cloud-run.sh [REGION] [SERVICE_NAME] [MEMORY_TARGET]
# Example: ./deploy-cloud-run.sh asia-southeast1 mem-load-85 85

REGION=${1:-asia-southeast1}
SERVICE_NAME=${2:-mem-load-default}
MEMORY_TARGET=${3:-50}
PROJECT_ID="rare-karma-480813-i3"

echo "🚀 Deploying Memory Load Generator to Cloud Run"
echo "================================"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"
echo "Memory Target: ${MEMORY_TARGET}%"
echo "================================"

# Step 1: Enable required APIs and create Artifact Registry repository
echo ""
echo "🔧 Step 1: Checking required APIs and Artifact Registry..."
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com run.googleapis.com --project=$PROJECT_ID --quiet 2>/dev/null || true

# Create Artifact Registry repository if not exists
REPO_NAME="cloud-run-source-deploy"
gcloud artifacts repositories describe $REPO_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || \
gcloud artifacts repositories create $REPO_NAME \
  --repository-format=docker \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null && echo "   ✓ Created Artifact Registry repository: $REPO_NAME"

echo "   ✓ APIs and repository ready"

# Step 2: Delete old service to avoid caching issues
echo ""
echo "🗑️  Step 2: Deleting old service (if exists)..."
gcloud run services delete $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --quiet 2>/dev/null || echo "   No existing service to delete"

# Step 3: Deploy to Cloud Run from source (Cloud Build will use correct architecture)
echo ""
echo "☁️  Step 3: Deploying to Cloud Run from source..."
echo "   Cloud Build will automatically build for correct architecture (AMD64)"
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --project $PROJECT_ID \
  --set-env-vars MEMORY_TARGET=$MEMORY_TARGET,STARTUP_DELAY=10,MEMORY_LIMIT=512 \
  --timeout 300 \
  --max-instances 1 \
  --min-instances 1 \
  --cpu 1 \
  --memory 512Mi \
  --port 8080 \
  --cpu-boost \
  --no-cpu-throttling \
  --allow-unauthenticated

echo "✅ Deployment complete!"

# Step 4: Get service URL and test
echo ""
echo "🔍 Step 4: Getting service information..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format 'value(status.url)')

echo ""
echo "================================"
echo "✅ SUCCESS!"
echo "================================"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"
echo "Service URL: $SERVICE_URL"
echo "Memory Target: ${MEMORY_TARGET}%"
echo ""
echo "📊 Check Memory usage:"
echo "  curl $SERVICE_URL"
echo ""
echo "📋 View logs:"
echo "  gcloud run services logs tail $SERVICE_NAME --region $REGION --project $PROJECT_ID"
echo ""
echo "ℹ️  Describe service:"
echo "  gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID"
echo ""
echo "🗑️  Delete service:"
echo "  gcloud run services delete $SERVICE_NAME --region $REGION --project $PROJECT_ID --quiet"
echo "================================"
