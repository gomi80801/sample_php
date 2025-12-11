#!/bin/bash
set -e

# Deploy all 3 Memory load services (75%, 85%, 95%) to Cloud Run
# Usage: ./deploy-all-cloud-run.sh [VERSION] [REGION]
# Example: ./deploy-all-cloud-run.sh v1.0 asia-southeast1

VERSION=${1:-v1.0}
REGION=${2:-asia-southeast1}
DOCKER_HUB_USER=${DOCKER_HUB_USER:-baonv}
IMAGE_NAME="mem-load-generator"

echo "🚀 Deploying ALL Memory Load Services to Cloud Run"
echo "================================"
echo "Docker Hub User: $DOCKER_HUB_USER"
echo "Image: $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION"
echo "Region: $REGION"
echo "Services: mem-load-75, mem-load-85, mem-load-95"
echo "================================"

# Step 1: Build Docker image once
echo ""
echo "📦 Step 1: Building Docker image..."
docker build -t $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION .
docker tag $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION $DOCKER_HUB_USER/$IMAGE_NAME:latest

echo "✅ Image built successfully"

# Step 2: Push to Docker Hub
echo ""
echo "📤 Step 2: Pushing to Docker Hub..."
echo "   Pushing $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION"
docker push $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION

echo "   Pushing $DOCKER_HUB_USER/$IMAGE_NAME:latest"
docker push $DOCKER_HUB_USER/$IMAGE_NAME:latest

echo "✅ Image pushed successfully"

# Step 3: Deploy all 3 services
echo ""
echo "☁️  Step 3: Deploying services to Cloud Run..."

# Deploy 75% Memory
echo ""
echo "📊 Deploying mem-load-75 (75% Memory target)..."
gcloud run deploy mem-load-75 \
  --image $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION \
  --region $REGION \
  --set-env-vars MEMORY_TARGET=75,STARTUP_DELAY=5 \
  --timeout 300 \
  --max-instances 1 \
  --cpu 1 \
  --memory 512Mi \
  --port 8080 \
  --no-cpu-throttling \
  --allow-unauthenticated \
  --quiet

echo "✅ mem-load-75 deployed"

# Deploy 85% Memory
echo ""
echo "📊 Deploying mem-load-85 (85% Memory target)..."
gcloud run deploy mem-load-85 \
  --image $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION \
  --region $REGION \
  --set-env-vars MEMORY_TARGET=85,STARTUP_DELAY=5 \
  --timeout 300 \
  --max-instances 1 \
  --cpu 1 \
  --memory 512Mi \
  --port 8080 \
  --no-cpu-throttling \
  --allow-unauthenticated \
  --quiet

echo "✅ mem-load-85 deployed"

# Deploy 95% Memory
echo ""
echo "📊 Deploying mem-load-95 (95% Memory target)..."
gcloud run deploy mem-load-95 \
  --image $DOCKER_HUB_USER/$IMAGE_NAME:$VERSION \
  --region $REGION \
  --set-env-vars MEMORY_TARGET=95,STARTUP_DELAY=5 \
  --timeout 300 \
  --max-instances 1 \
  --cpu 1 \
  --memory 512Mi \
  --port 8080 \
  --no-cpu-throttling \
  --allow-unauthenticated \
  --quiet

echo "✅ mem-load-95 deployed"

# Step 4: Get service URLs
echo ""
echo "🔍 Step 4: Getting service URLs..."

URL_75=$(gcloud run services describe mem-load-75 --region $REGION --format 'value(status.url)')
URL_85=$(gcloud run services describe mem-load-85 --region $REGION --format 'value(status.url)')
URL_95=$(gcloud run services describe mem-load-95 --region $REGION --format 'value(status.url)')

echo ""
echo "================================"
echo "✅ ALL SERVICES DEPLOYED!"
echo "================================"
echo ""
echo "📊 Memory Load 75%:"
echo "   URL: $URL_75"
echo "   Test: curl $URL_75/health"
echo ""
echo "📊 Memory Load 85%:"
echo "   URL: $URL_85"
echo "   Test: curl $URL_85/health"
echo ""
echo "📊 Memory Load 95%:"
echo "   URL: $URL_95"
echo "   Test: curl $URL_95/health"
echo ""
echo "================================"
echo "View logs:"
echo "  gcloud run services logs tail mem-load-75 --region $REGION"
echo "  gcloud run services logs tail mem-load-85 --region $REGION"
echo "  gcloud run services logs tail mem-load-95 --region $REGION"
echo ""
echo "Delete all services:"
echo "  gcloud run services delete mem-load-75 --region $REGION --quiet"
echo "  gcloud run services delete mem-load-85 --region $REGION --quiet"
echo "  gcloud run services delete mem-load-95 --region $REGION --quiet"
echo "================================"

# Optional: Test all services
read -p "🔍 Test all services now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo ""
    echo "Testing mem-load-75..."
    curl -s $URL_75/health
    echo ""
    echo ""
    echo "Testing mem-load-85..."
    curl -s $URL_85/health
    echo ""
    echo ""
    echo "Testing mem-load-95..."
    curl -s $URL_95/health
    echo ""
    echo ""
    echo "✅ All health checks passed!"
fi
