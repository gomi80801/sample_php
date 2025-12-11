# Auto-Failover Monitor - Cloud Run Service

## Setup

### 1. Build và Deploy Monitor Service

```bash
cd monitor-service

# Build và push image
docker build -t gcr.io/my-project-1101-476915/auto-failover-monitor .
docker push gcr.io/my-project-1101-476915/auto-failover-monitor

# Deploy to Cloud Run
./deploy.sh
```

### 2. Setup Service Account Permissions

Monitor service cần quyền để update backend service:

```bash
set PROJECT_ID "my-project-1101-476915"

# Grant Load Balancer Admin role
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:failover-monitor@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/compute.loadBalancerAdmin"
```

### 3. Setup Cloud Scheduler để gọi monitor endpoint

```bash
# Lấy monitor service URL (fish shell)
set MONITOR_URL (gcloud run services describe auto-failover-monitor --region=asia-northeast1 --format='value(status.url)')

# Hoặc nếu dùng bash:
# MONITOR_URL=$(gcloud run services describe auto-failover-monitor --region=asia-northeast1 --format='value(status.url)')

# Tạo Cloud Scheduler job chạy mỗi phút
set PROJECT_ID "my-project-1101-476915"
gcloud scheduler jobs create http failover-monitor-job \
  --location=asia-northeast1 \
  --schedule="*/1 * * * *" \
  --uri="$MONITOR_URL/monitor" \
  --http-method=GET \
  --attempt-deadline=60s \
  --oidc-service-account-email=failover-monitor@$PROJECT_ID.iam.gserviceaccount.com
```

## Endpoints

### GET /
Health check endpoint
```bash
curl $MONITOR_URL/
```

### GET /monitor
Main monitoring endpoint - triggers health check and failover if needed
```bash
curl $MONITOR_URL/monitor
```

Response:
```json
{
  "timestamp": "2025-11-29 12:00:00",
  "tokyo_healthy": false,
  "osaka_healthy": true,
  "current_active": "osaka",
  "action": "FAILOVER TO OSAKA"
}
```

### GET /status
Check status without making changes
```bash
curl $MONITOR_URL/status
```

## Test Failover

### Test 1: Check Status
```bash
# Fish shell
set MONITOR_URL "https://auto-failover-monitor-zocpikyq2a-an.a.run.app"
curl $MONITOR_URL/status

# Bash
# MONITOR_URL="https://auto-failover-monitor-zocpikyq2a-an.a.run.app"
# curl ${MONITOR_URL}/status
```

### Test 2: Trigger Manual Check
```bash
curl $MONITOR_URL/monitor
```

### Test 3: Xóa Tokyo và xem auto-failover
```bash
# Xóa Tokyo
gcloud run services delete app-tokyo --region=asia-northeast1 --quiet

# Đợi 1 phút cho scheduler chạy
sleep 60

# Check logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=auto-failover-monitor" \
  --limit=20 \
  --format=json

# Hoặc trigger manual
curl $MONITOR_URL/monitor
```

## View Logs

```bash
# Real-time logs
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=auto-failover-monitor"

# Last 20 entries
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=auto-failover-monitor" \
  --limit=20 \
  --format="table(timestamp,severity,textPayload)"
```

## Architecture

```
┌─────────────────────────────────┐
│   Cloud Scheduler (Every 1min)  │
└──────────────┬──────────────────┘
               │ GET /monitor
               ↓
┌─────────────────────────────────┐
│ Cloud Run: auto-failover-monitor│
│  - Check Tokyo health           │
│  - Check Osaka health           │
│  - Update backend if needed     │
└──────────────┬──────────────────┘
               │ gcloud API
               ↓
┌─────────────────────────────────┐
│  Backend Service (ALB)          │
│  - Remove Tokyo backend         │
│  - Add Osaka backend            │
└─────────────────────────────────┘
```

## Timeline

```
0:00  Tokyo fails
1:00  Scheduler triggers /monitor
1:01  Detect Tokyo unhealthy
1:02  Update backend service (remove Tokyo, keep Osaka)
3:00  Config propagate complete
3:00+ 100% traffic to Osaka ✓
```

**Total: ~3 minutes**

## Cost

- Cloud Run (monitor): ~$1/month (minimal usage)
- Cloud Scheduler: $0.10/month
- **Total: ~$1.10/month**

## Troubleshooting

### View detailed logs
```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=auto-failover-monitor AND severity>=WARNING" \
  --limit=50 \
  --format=json | jq '.[] | {timestamp, severity, message: .textPayload}'
```

### Test locally
```bash
cd monitor-service
export PROJECT_ID="my-project-1101-476915"
export PORT=8080
python main.py
```

### Manually trigger failover
```bash
curl $MONITOR_URL/monitor
```

## Update Code

```bash
cd monitor-service
# Edit main.py
docker build -t gcr.io/my-project-1101-476915/auto-failover-monitor .
docker push gcr.io/my-project-1101-476915/auto-failover-monitor
gcloud run deploy auto-failover-monitor --image=gcr.io/my-project-1101-476915/auto-failover-monitor --region=asia-northeast1
```

## Advantages vs Local Cron

✅ **Không cần local machine chạy 24/7**
✅ **Cloud Run auto-scale**
✅ **Logging tập trung trên GCP**
✅ **Không cần Terraform trên production**
✅ **Dễ debug và monitor**
✅ **Production-ready**
