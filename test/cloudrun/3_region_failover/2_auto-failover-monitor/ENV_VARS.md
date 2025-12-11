# Auto-Failover Monitor Service - Environment Variables

## Overview
Service này được thiết kế để có thể tái sử dụng cho nhiều hệ thống khác nhau thông qua việc cấu hình hoàn toàn bằng biến môi trường.

## Required Environment Variables

### 1. Core Settings
- **PROJECT_ID**: GCP Project ID
  - Example: `my-project-1101-476915`
  
- **PRIMARY_REGION**: Primary region (ưu tiên sử dụng)
  - Example: `asia-northeast1` (Tokyo)
  
- **SECONDARY_REGION**: Secondary region (dự phòng)
  - Example: `asia-northeast2` (Osaka)

### 2. Health Check URLs
- **PRIMARY_URL**: URL của Cloud Run service ở primary region
  - Example: `https://app-tokyo-zocpikyq2a-an.a.run.app`
  
- **SECONDARY_URL**: URL của Cloud Run service ở secondary region
  - Example: `https://app-osaka-zocpikyq2a-dt.a.run.app`

### 3. Backend Services Configuration
- **BACKEND_CONFIG_JSON**: JSON string chứa cấu hình các backend services và NEGs tương ứng
  - Format: `{"backend-service-name": {"primary_neg": "neg-name", "secondary_neg": "neg-name"}}`
  - Example:
  ```json
  {
    "global-backend-service": {
      "primary_neg": "tokyo-serverless-neg",
      "secondary_neg": "osaka-serverless-neg"
    },
    "response-backend-service": {
      "primary_neg": "tokyo-response-serverless-neg",
      "secondary_neg": "osaka-response-serverless-neg"
    }
  }
  ```

## Configuration File

Sử dụng file `env.yaml` để cấu hình khi deploy:

```yaml
PROJECT_ID: your-project-id
PRIMARY_REGION: asia-northeast1
SECONDARY_REGION: asia-northeast2
PRIMARY_URL: https://your-primary-service.run.app
SECONDARY_URL: https://your-secondary-service.run.app
BACKEND_CONFIG_JSON: >-
  {
    "your-backend-service": {
      "primary_neg": "primary-neg-name",
      "secondary_neg": "secondary-neg-name"
    }
  }
```

## Deploy Command

```bash
gcloud run deploy auto-failover-monitor \
  --image=gcr.io/PROJECT_ID/auto-failover-monitor \
  --region=asia-northeast1 \
  --env-vars-file=env.yaml \
  --min-instances=1 \
  --memory=768Mi
```

## Example Configurations

### Single Backend Service
```json
{
  "backend-service": {
    "primary_neg": "primary-neg",
    "secondary_neg": "secondary-neg"
  }
}
```

### Multiple Backend Services
```json
{
  "api-backend": {
    "primary_neg": "tokyo-api-neg",
    "secondary_neg": "osaka-api-neg"
  },
  "web-backend": {
    "primary_neg": "tokyo-web-neg",
    "secondary_neg": "osaka-web-neg"
  },
  "admin-backend": {
    "primary_neg": "tokyo-admin-neg",
    "secondary_neg": "osaka-admin-neg"
  }
}
```

### Different Regions
```yaml
PROJECT_ID: another-project-id
PRIMARY_REGION: us-central1
SECONDARY_REGION: us-east1
PRIMARY_URL: https://app-us-central.run.app
SECONDARY_URL: https://app-us-east.run.app
BACKEND_CONFIG_JSON: >-
  {
    "my-backend": {
      "primary_neg": "us-central-neg",
      "secondary_neg": "us-east-neg"
    }
  }
```

## API Endpoints

### GET /status
Trả về trạng thái hiện tại của tất cả backend services mà không thay đổi gì:
```json
{
  "primary_healthy": true,
  "primary_region": "asia-northeast1",
  "primary_url": "https://app-tokyo.run.app",
  "secondary_healthy": true,
  "secondary_region": "asia-northeast2",
  "secondary_url": "https://app-osaka.run.app",
  "backend_services": {
    "global-backend-service": "primary",
    "response-backend-service": "primary"
  }
}
```

### GET /monitor
Thực hiện health check và tự động failover nếu cần:
```json
{
  "timestamp": "Sat Nov 30 10:00:00 UTC 2025",
  "primary_healthy": false,
  "primary_region": "asia-northeast1",
  "secondary_healthy": true,
  "secondary_region": "asia-northeast2",
  "backend_services": {
    "global-backend-service": {
      "current_active": "secondary",
      "action": "FAILOVER TO SECONDARY (asia-northeast2)"
    }
  }
}
```

## Migration Guide

Để áp dụng cho hệ thống mới:

1. **Copy files cần thiết:**
   - `main.py`
   - `Dockerfile`
   - `requirements.txt`
   - `deploy.sh`
   - `env.example.yaml`

2. **Tạo file env.yaml mới** dựa trên `env.example.yaml`:
   - Thay đổi PROJECT_ID
   - Cập nhật PRIMARY_REGION và SECONDARY_REGION
   - Thay đổi PRIMARY_URL và SECONDARY_URL
   - Cấu hình BACKEND_CONFIG_JSON với danh sách backend services và NEGs

3. **Deploy:**
   ```bash
   ./deploy.sh
   ```

4. **Setup Cloud Scheduler** (nếu muốn auto-monitoring):
   ```bash
   gcloud scheduler jobs create http auto-failover-job \
     --location=asia-northeast1 \
     --schedule="*/1 * * * *" \
     --uri="https://your-monitor-url.run.app/monitor" \
     --http-method=GET
   ```

## Notes

- Service sử dụng terminology "primary/secondary" thay vì "tokyo/osaka" để dễ dàng áp dụng cho các region khác
- NEG names chỉ cần tên ngắn (không cần full URL), service sẽ tự động build full URL
- Backend service names phải match chính xác với tên trong GCP
- Khuyến khích sử dụng `--min-instances=1` để tránh cold start cho monitoring service
