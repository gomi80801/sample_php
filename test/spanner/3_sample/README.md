# Spanner CPU Metric Pusher

Script Python để push custom CPU metrics lên Google Cloud Monitoring cho Spanner resource.

## 🚀 Quick Start

### Option 1: Using test script (Recommended)

```bash
# Set your project ID
export GCP_PROJECT_ID="your-project-id"

# Optional: customize other settings
export SPANNER_INSTANCE_ID="your-instance-id"  # Default: test-instance
export CPU_PERCENTAGE=75                        # Default: 75
export PUSH_INTERVAL=5                          # Default: 5 seconds

# Run test script (handles installation & auth)
./test.sh
```

### Option 2: Manual setup

#### 1. Cài đặt dependencies

```bash
pip install -r requirements.txt
```

#### 2. Authenticate với GCP

```bash
gcloud auth application-default login
```

#### 3. Set environment variables

```bash
export GCP_PROJECT_ID="your-project-id"
export SPANNER_INSTANCE_ID="your-instance-id"  # Optional, default: test-instance
export CPU_PERCENTAGE=75                        # Optional, default: 75
export PUSH_INTERVAL=5                          # Optional, default: 5 seconds
```

#### 4. Chạy script

```bash
python3 push_cpu_metric.py
```

## 📊 Output mẫu

```
[2025-11-13 07:30:00] ===== Spanner CPU Metric Pusher Started =====
[2025-11-13 07:30:00] Project: my-project-id
[2025-11-13 07:30:00] Instance: test-instance
[2025-11-13 07:30:00] CPU Target: 75%
[2025-11-13 07:30:00] Push Interval: 5s
[2025-11-13 07:30:00] ============================================
[2025-11-13 07:30:00] ℹ️  Metric descriptor already exists
[2025-11-13 07:30:00] ✅ Pushed metric: CPU=75% for instance=test-instance
[2025-11-13 07:30:05] ✅ Pushed metric: CPU=75% for instance=test-instance
[2025-11-13 07:30:10] ✅ Pushed metric: CPU=75% for instance=test-instance
...
```

## 🔧 Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `GCP_PROJECT_ID` | GCP Project ID (required) | - |
| `SPANNER_INSTANCE_ID` | Spanner Instance ID | `test-instance` |
| `CPU_PERCENTAGE` | CPU usage percentage to report | `75` |
| `PUSH_INTERVAL` | Interval between pushes (seconds) | `5` |

## 📈 View Metrics

### Metrics Explorer

1. Go to [Cloud Console](https://console.cloud.google.com/monitoring)
2. Navigate to **Monitoring** → **Metrics Explorer**
3. Search for: `custom.googleapis.com/spanner/cpu_utilization_simulated`
4. Filter by `instance_id`

### MQL Query

```sql
fetch global
| metric 'custom.googleapis.com/spanner/cpu_utilization_simulated'
| filter instance_id == 'test-instance'
| group_by 1m, [value_cpu_utilization_simulated_mean: mean(value.cpu_utilization_simulated)]
```

## 🛑 Stop Script

Press `Ctrl+C` to stop the script gracefully.

## 💡 Tips

- Script tự động tạo custom metric descriptor nếu chưa tồn tại
- Metrics có thể mất 1-2 phút để hiển thị trong Cloud Console
- Sử dụng `global` resource type cho custom metrics
- Có thể thay đổi CPU percentage bằng cách set `CPU_PERCENTAGE` env var

## 🐳 Run with Docker (Optional)

```bash
# Build
docker build -t spanner-metric-pusher .

# Run
docker run -it \
  -v ~/.config/gcloud:/root/.config/gcloud \
  -e GCP_PROJECT_ID=your-project-id \
  -e SPANNER_INSTANCE_ID=test-instance \
  -e CPU_PERCENTAGE=75 \
  spanner-metric-pusher
```
