# Tại Sao Xóa Cloud Run Không Tự Động Failover?

## Vấn Đề

Khi bạn **xóa Cloud Run ở Tokyo**, requests vẫn bị lỗi (502 Bad Gateway) thay vì tự động chuyển sang Osaka vì:

### 1. **Serverless NEG vẫn tồn tại**
```
Cloud Run Tokyo (Deleted) ❌
    ↓
Serverless NEG Tokyo (Still exists) ✓
    ↓
Load Balancer (Still routes 50% traffic here) ❌
```

### 2. **Không có Health Check**
- Serverless NEG (Cloud Run) **không hỗ trợ health checks**
- Load Balancer không biết Cloud Run đã bị xóa
- Vẫn tiếp tục route traffic đến NEG (dù backend không còn)

### 3. **Round-Robin Load Balancing**
- Với 2 backends active (capacity_scaler = 1.0), traffic được chia đều 50-50
- Khi Tokyo bị xóa: 50% requests thành công (Osaka), 50% lỗi 502 (Tokyo NEG)

## Kiến Trúc Thực Tế

```
┌─────────────────────────────────────────────────┐
│         Global Load Balancer                     │
│              (34.102.181.192)                    │
└──────────────┬──────────────────┬────────────────┘
               │                  │
               │ 50%              │ 50%
               ↓                  ↓
      ┌────────────────┐  ┌────────────────┐
      │ Tokyo NEG      │  │ Osaka NEG      │
      │ capacity=1.0   │  │ capacity=1.0   │
      └───────┬────────┘  └───────┬────────┘
              ↓                   ↓
      ┌────────────────┐  ┌────────────────┐
      │ Cloud Run      │  │ Cloud Run      │
      │ (DELETED ❌)   │  │ (Active ✓)     │
      └────────────────┘  └────────────────┘

Result: 50% success, 50% error 502
```

## Giải Pháp

### ❌ KHÔNG NÊN: Xóa Cloud Run để test failover
```bash
# Sai - NEG vẫn tồn tại, gây lỗi 502
gcloud run services delete app-tokyo --region=asia-northeast1
```

### ✅ NÊN: Dùng capacity_scaler để điều khiển traffic
```bash
# Đúng - Chỉ route traffic đến Osaka
terraform apply \
  -var="tokyo_capacity=0.0" \
  -var="osaka_capacity=1.0" \
  -auto-approve
```

## Các Scenario Failover

### 1. Tokyo Primary, Osaka Standby (Default)
```bash
terraform apply -var="tokyo_capacity=1.0" -var="osaka_capacity=0.0" -auto-approve
```
- 100% traffic → Tokyo
- Osaka ở chế độ standby (sẵn sàng nhưng không nhận traffic)

### 2. Simulate Tokyo Failure → Failover to Osaka
```bash
terraform apply -var="tokyo_capacity=0.0" -var="osaka_capacity=1.0" -auto-approve
# Đợi 2-3 phút để config propagate
```
- 0% traffic → Tokyo
- 100% traffic → Osaka

### 3. Both Regions Active (Load Distribution)
```bash
terraform apply -var="tokyo_capacity=1.0" -var="osaka_capacity=1.0" -auto-approve
```
- 50% traffic → Tokyo
- 50% traffic → Osaka

### 4. Weighted Distribution
```bash
terraform apply -var="tokyo_capacity=0.8" -var="osaka_capacity=0.2" -auto-approve
```
- 80% traffic → Tokyo
- 20% traffic → Osaka

## Thời Gian Propagate

⏱️ **Global Load Balancer cần 2-3 phút** để áp dụng thay đổi:
- Backend configuration update: ~30 seconds
- Global routing propagation: ~90-180 seconds
- Total: **2-3 minutes** để hoàn toàn failover

## Test Đúng Cách

Chạy script test mới:
```bash
./test-correct-failover.sh
```

Script này sẽ:
1. ✅ Test Tokyo active (capacity=1.0)
2. ✅ Simulate failure bằng capacity=0.0
3. ✅ Đợi 120s cho config propagate
4. ✅ Verify traffic chuyển sang Osaka
5. ✅ Test cả 2 regions active
6. ✅ Restore Tokyo primary

## Commands Hữu Ích

```bash
# Check backend configuration
gcloud compute backend-services describe global-backend-service \
  --global --format="yaml(backends)"

# Quick failover to Osaka
terraform apply -var="tokyo_capacity=0.0" -var="osaka_capacity=1.0" -auto-approve

# Restore Tokyo
terraform apply -var="tokyo_capacity=1.0" -var="osaka_capacity=0.0" -auto-approve

# Enable both (50-50)
terraform apply -var="tokyo_capacity=1.0" -var="osaka_capacity=1.0" -auto-approve

# Test with response code
curl -w "\nHTTP: %{http_code}\n" http://34.102.181.192
```

## Kết Luận

🔑 **Key Takeaway:**
- ❌ Xóa Cloud Run ≠ Automatic Failover
- ✅ Dùng `capacity_scaler` = True Failover Control
- ⏱️ Đợi 2-3 phút cho config propagate
- 📊 Test bằng `test-correct-failover.sh`
