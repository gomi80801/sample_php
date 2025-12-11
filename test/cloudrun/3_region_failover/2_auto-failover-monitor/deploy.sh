#!/bin/bash

# Deploy Auto-Failover Monitor Service to Cloud Run

PROJECT_ID="my-project-1101-476915"
SERVICE_NAME="auto-failover-monitor"
REGION="asia-northeast2"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "Building Docker image for linux/amd64..."
docker build --platform linux/amd64 -t ${IMAGE_NAME} .

echo "Pushing image to GCR..."
docker push ${IMAGE_NAME}

echo "Checking env.yaml file..."
if [ ! -f env.yaml ]; then
  echo "❌ Error: env.yaml not found!"
  echo "Please create env.yaml from env.example.yaml"
  exit 1
fi

echo "Deploying to Cloud Run with minimum instances (no cold start)..."
gcloud run deploy ${SERVICE_NAME} \
  --image=${IMAGE_NAME} \
  --platform=managed \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --allow-unauthenticated \
  --memory=768Mi \
  --cpu=1 \
  --min-instances=1 \
  --max-instances=2 \
  --env-vars-file=env.yaml

# Grant Load Balancer Admin role to default compute service account
echo "Granting Load Balancer Admin role to default service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:415553820463-compute@developer.gserviceaccount.com" \
  --role="roles/compute.loadBalancerAdmin" \
  --condition=None

echo ""
sleep 10
echo "Service deployed!"
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format='value(status.url)')
STATUS_URL="${SERVICE_URL}/status"
echo "Status URL: ${STATUS_URL}"
MONITOR_URL="${SERVICE_URL}/monitor"
echo "Monitor URL: ${MONITOR_URL}"

# Create Cloud Scheduler job for auto-failover monitoring (every 1 minute)
echo ""
echo "Creating Cloud Scheduler job..."
JOB_NAME="auto-failover-monitor-job"

# Check if job already exists
if gcloud scheduler jobs describe ${JOB_NAME} --location=${REGION} --project=${PROJECT_ID} &>/dev/null; then
  echo "Scheduler job already exists. Updating..."
  gcloud scheduler jobs update http ${JOB_NAME} \
    --location=${REGION} \
    --schedule="*/1 * * * *" \
    --uri="${MONITOR_URL}" \
    --http-method=GET \
    --project=${PROJECT_ID}
else
  echo "Creating new scheduler job..."
  gcloud scheduler jobs create http ${JOB_NAME} \
    --location=${REGION} \
    --schedule="*/1 * * * *" \
    --uri="${MONITOR_URL}" \
    --http-method=GET \
    --project=${PROJECT_ID}
fi

echo ""
echo "✅ Deployment complete!"
echo "📊 Status URL: ${STATUS_URL}"
echo "📊 Monitor URL: ${MONITOR_URL}"
echo "⏰ Scheduler Job: ${JOB_NAME} (runs every 1 minute)"
echo "=========================================="

sleep 10
curl -s $STATUS_URL | jq