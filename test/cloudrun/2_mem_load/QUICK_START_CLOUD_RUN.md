# Quick Start Guide - Memory Load Generator (Cloud Run)

Deploy Memory load testing services to Google Cloud Run with automatic build from source.

## 🚀 Quick Deploy

### Prerequisites

```bash
# Login to gcloud
gcloud auth login

# Set project
gcloud config set project rare-karma-480813-i3

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## ☁️ Deploy Services

### Option 1: Using Deploy Script (Recommended)

The script automatically builds from source and deploys to Cloud Run with correct architecture.

**Usage:**
```bash
./deploy-cloud-run.sh [REGION] [SERVICE_NAME] [MEMORY_TARGET]
```

**Examples:**

```bash
# Deploy with default values (asia-southeast1, mem-load-default, 50% Memory)
./deploy-cloud-run.sh

# Deploy 75% Memory load service
./deploy-cloud-run.sh asia-southeast1 mem-load-75 75

# Deploy 85% Memory load service
./deploy-cloud-run.sh asia-southeast1 mem-load-85 85

# Deploy 95% Memory load service
./deploy-cloud-run.sh asia-southeast1 mem-load-95 95
```
