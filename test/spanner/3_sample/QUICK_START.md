# Quick Start - Spanner CPU Metric Pusher

## 🎯 Mục đích

Push custom CPU metrics (75%) lên Google Cloud Monitoring mỗi 5 giây một lần.

## ⚡ Chạy nhanh (3 bước)

```bash
# 1. Set project ID
export GCP_PROJECT_ID="my-project-1101-476915"

# 2. Run
cd 9_test/spanner
./test.sh
```

Script sẽ tự động:
- ✅ Install dependencies
- ✅ Check authentication
- ✅ Push metrics mỗi 5s

## 🛑 Dừng script

Press `Ctrl+C`

## 📊 Xem metrics

1. Go to: https://console.cloud.google.com/monitoring
2. **Metrics Explorer** → Search: `cpu_utilization_simulated`
3. Filter by `instance_id`

## 🔧 Customize

```bash
# Thay đổi CPU percentage
export CPU_PERCENTAGE=85

# Thay đổi push interval
export PUSH_INTERVAL=10

# Thay đổi instance ID
export SPANNER_INSTANCE_ID=my-instance

# Run
./test.sh
```

## 📝 Files

- `push_cpu_metric.py` - Main script
- `test.sh` - Quick test script (recommended)
- `requirements.txt` - Python dependencies
- `README.md` - Full documentation
