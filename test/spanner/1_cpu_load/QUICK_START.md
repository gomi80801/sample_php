# Quick Start Guide - Spanner CPU Load Generator (Cloud Run)

Deploy Spanner load testing services to Google Cloud Run with automatic build from source.

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
gcloud services enable spanner.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### Create Spanner Instance (if not exists)

```bash
# Create dual-region Spanner instance (Tokyo + Osaka)
gcloud spanner instances create my-spanner-instance \
  --config=asia-northeast1 \
  --description="Load Test Instance" \
  --nodes=1 \
  --project=rare-karma-480813-i3

# Or use existing instance
export SPANNER_INSTANCE_ID="your-existing-instance"
```

## ☁️ Deploy Services

### Option 1: Using Deploy Script (Recommended)

The script automatically builds from source and deploys to Cloud Run with correct architecture.

**Usage:**
```bash
./deploy-cloud-run.sh [REGION] [SERVICE_NAME] [CPU_TARGET] [SPANNER_INSTANCE_ID]
```

**Examples:**

```bash
# Deploy 75% CPU load service
./deploy-cloud-run.sh asia-northeast1 spanner-load-75 75 my-spanner-instance

# Deploy 85% CPU load service
./deploy-cloud-run.sh asia-northeast1 spanner-load-85 85 my-spanner-instance

# Deploy 95% CPU load service
./deploy-cloud-run.sh asia-northeast1 spanner-load-95 95 my-spanner-instance
```

**What the script does:**
- ✅ Validates Spanner instance exists
- ✅ Creates database automatically if not exists
- ✅ Creates test table automatically (LoadTestData)
- ✅ Deploys load generator to Cloud Run
- ✅ Returns dashboard URL and monitoring links

### Option 2: Manual Deploy

```bash
# Set variables
export SPANNER_INSTANCE_ID="my-spanner-instance"
export REGION="asia-northeast1"

# Deploy 75% load
gcloud run deploy spanner-load-75 \
  --source . \
  --region $REGION \
  --project rare-karma-480813-i3 \
  --set-env-vars GCP_PROJECT_ID=rare-karma-480813-i3,SPANNER_INSTANCE_ID=$SPANNER_INSTANCE_ID,SPANNER_DATABASE_ID=loadtest,CPU_TARGET=75 \
  --timeout 3600 \
  --max-instances 1 \
  --min-instances 1 \
  --cpu 2 \
  --memory 1Gi \
  --no-cpu-throttling \
  --allow-unauthenticated
```

## 📊 Monitor & Check Status

### View Service Dashboard

```bash
# Get service URL
URL=$(gcloud run services describe spanner-load-75 --region asia-northeast1 --format 'value(status.url)')

# Open dashboard in browser
open $URL
```

### View Spanner Metrics

```bash
# View in GCP Console
open "https://console.cloud.google.com/spanner/instances/$SPANNER_INSTANCE_ID/monitoring?project=rare-karma-480813-i3"

# View logs
gcloud run services logs tail spanner-load-75 --region asia-northeast1
```

## 🗑️ Cleanup

```bash
# Delete Cloud Run services
gcloud run services delete spanner-load-75 --region asia-northeast1 --quiet
gcloud run services delete spanner-load-85 --region asia-northeast1 --quiet
gcloud run services delete spanner-load-95 --region asia-northeast1 --quiet

# Optional: Delete test database
gcloud spanner databases delete loadtest \
  --instance=$SPANNER_INSTANCE_ID \
  --quiet
```

## 🧪 Test Local

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GCP_PROJECT_ID="rare-karma-480813-i3"
export SPANNER_INSTANCE_ID="my-spanner-instance"
export SPANNER_DATABASE_ID="loadtest"
export CPU_TARGET=75
export PORT=8080

# Run load generator
python spanner_load_with_http.py

# Open browser
open http://localhost:8080
```

## 📊 How It Works

**Load Generator performs:**
1. **INSERT** operations - Add new records
2. **READ** operations - Complex queries with aggregations
3. **UPDATE** operations - Batch updates with transactions
4. **SCAN** operations - Full table scans (CPU intensive)

**Workload Distribution:**
- 30% INSERT
- 40% READ
- 20% UPDATE
- 10% SCAN

**Load Control:**
- 75% CPU = 10 threads, ~500 ops/sec
- 85% CPU = 15 threads, ~1000 ops/sec
- 95% CPU = 25 threads, ~2000 ops/sec

## 💡 Tips

- Spanner CPU thường mất 2-5 phút để lên đến target level
- Monitor trong GCP Console để điều chỉnh parameters
- Có thể scale Cloud Run instances để tăng/giảm load
- Dual region (Tokyo + Osaka) sẽ distribute load across regions

## 🔧 Tuning

Nếu không đạt target CPU, điều chỉnh trong `spanner_cpu_load.py`:

```python
# Increase threads
thread_map = {
    75: 15,   # Tăng từ 10
    85: 20,   # Tăng từ 15
    95: 30    # Tăng từ 25
}

# Increase operations per second
ops_map = {
    75: 800,   # Tăng từ 500
    85: 1500,  # Tăng từ 1000
    95: 3000   # Tăng từ 2000
}
```
