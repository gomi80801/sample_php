#!/bin/bash
set -e

# Deploy Spanner Load Generator to Cloud Run
# Usage: ./deploy-cloud-run.sh [REGION] [SERVICE_NAME] [CPU_TARGET] [SPANNER_INSTANCE_ID]
# Example: ./deploy-cloud-run.sh asia-northeast1 spanner-load-85 85 my-spanner-instance

REGION=${1:-asia-northeast1}
SERVICE_NAME=${2:-spanner-load-default}
CPU_TARGET=${3:-75}
SPANNER_INSTANCE_ID=${4}
PROJECT_ID="rare-karma-480813-i3"
SPANNER_DATABASE_ID="loadtest"

# Validate Spanner instance ID
if [ -z "$SPANNER_INSTANCE_ID" ]; then
    echo "❌ ERROR: SPANNER_INSTANCE_ID is required"
    echo ""
    echo "Usage: ./deploy-cloud-run.sh [REGION] [SERVICE_NAME] [CPU_TARGET] [SPANNER_INSTANCE_ID]"
    echo ""
    echo "Example:"
    echo "  ./deploy-cloud-run.sh asia-northeast1 spanner-load-85 85 my-spanner-instance"
    exit 1
fi

echo "🚀 Deploying Spanner Load Generator to Cloud Run"
echo "================================"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"
echo "Spanner Instance: $SPANNER_INSTANCE_ID"
echo "Spanner Database: $SPANNER_DATABASE_ID"
echo "CPU Target: ${CPU_TARGET}%"
echo "================================"

# Step 1: Enable required APIs and create Artifact Registry repository
echo ""
echo "🔧 Step 1: Checking required APIs and Artifact Registry..."
gcloud services enable artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  spanner.googleapis.com \
  monitoring.googleapis.com \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || true

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

# Step 2: Verify Spanner instance exists
echo ""
echo "🗄️  Step 2: Verifying Spanner instance..."
if gcloud spanner instances describe $SPANNER_INSTANCE_ID \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null; then
    echo "   ✓ Spanner instance '$SPANNER_INSTANCE_ID' found"
else
    echo "   ❌ Spanner instance '$SPANNER_INSTANCE_ID' not found"
    echo ""
    echo "Create instance first:"
    echo "  gcloud spanner instances create $SPANNER_INSTANCE_ID \\"
    echo "    --config=nam3 \\"
    echo "    --description='Load Test Instance' \\"
    echo "    --nodes=1 \\"
    echo "    --project=$PROJECT_ID"
    exit 1
fi

# Step 3: Create database if not exists
echo ""
echo "🗄️  Step 3: Checking/Creating database..."
if gcloud spanner databases describe $SPANNER_DATABASE_ID \
  --instance=$SPANNER_INSTANCE_ID \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null; then
    echo "   ✓ Database '$SPANNER_DATABASE_ID' already exists"
else
    echo "   Creating database '$SPANNER_DATABASE_ID'..."
    gcloud spanner databases create $SPANNER_DATABASE_ID \
      --instance=$SPANNER_INSTANCE_ID \
      --project=$PROJECT_ID \
      --quiet
    echo "   ✓ Database created"
fi

# Step 4: Delete old service to avoid caching issues
echo ""
echo "🗑️  Step 4: Deleting old service (if exists)..."
gcloud run services delete $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --quiet 2>/dev/null || echo "   No existing service to delete"

# Step 5: Deploy to Cloud Run from source
echo ""
echo "☁️  Step 5: Deploying to Cloud Run from source..."
echo "   Cloud Build will automatically build for correct architecture (AMD64)"
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --project $PROJECT_ID \
  --set-env-vars GCP_PROJECT_ID=$PROJECT_ID,SPANNER_INSTANCE_ID=$SPANNER_INSTANCE_ID,SPANNER_DATABASE_ID=$SPANNER_DATABASE_ID,CPU_TARGET=$CPU_TARGET \
  --timeout 3600 \
  --max-instances 1 \
  --min-instances 1 \
  --cpu 2 \
  --memory 1Gi \
  --port 8080 \
  --cpu-boost \
  --no-cpu-throttling \
  --allow-unauthenticated

echo "✅ Deployment complete!"

# Step 6: Get service URL and test
echo ""
echo "🔍 Step 6: Getting service information..."
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
echo ""
echo "Spanner Configuration:"
echo "  Instance: $SPANNER_INSTANCE_ID"
echo "  Database: $SPANNER_DATABASE_ID"
echo "  CPU Target: ${CPU_TARGET}%"
echo ""
echo "📊 View dashboard:"
echo "  open $SERVICE_URL"
echo ""
echo "📊 Monitor Spanner CPU:"
echo "  https://console.cloud.google.com/spanner/instances/$SPANNER_INSTANCE_ID/monitoring?project=$PROJECT_ID"
echo ""
echo "📋 View logs:"
echo "  gcloud run services logs tail $SERVICE_NAME --region $REGION --project $PROJECT_ID"
echo ""
echo "ℹ️  Describe service:"
echo "  gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID"
echo ""
echo "🗑️  Delete service:"
echo "  gcloud run services delete $SERVICE_NAME --region $REGION --project $PROJECT_ID --quiet"
echo ""
echo "🗑️  Delete database (optional):"
echo "  gcloud spanner databases delete $SPANNER_DATABASE_ID --instance=$SPANNER_INSTANCE_ID --project=$PROJECT_ID --quiet"
echo "================================"
echo ""
echo "⏳ Note: Spanner CPU may take 2-5 minutes to reach target level"
echo "   Monitor the dashboard and Spanner console for real-time metrics"
