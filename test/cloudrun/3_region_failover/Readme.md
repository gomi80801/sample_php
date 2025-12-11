# Terraform Configuration for 3 ALBs with Auto-Failover

## Architecture Overview

This configuration creates 3 independent Application Load Balancers (ALBs), each serving 2 paths with automatic failover between Tokyo and Osaka regions.

### ALB1
- **Main Path (`/`)**: `app1-main-tokyo` → failover to `app1-main-osaka`
- **Response Path (`/response`)**: `app1-response-tokyo` → failover to `app1-response-osaka`

### ALB2
- **Main Path (`/`)**: `app2-main-tokyo` → failover to `app2-main-osaka`
- **Response Path (`/response`)**: `app2-response-tokyo` → failover to `app2-response-osaka`

### ALB3
- **Main Path (`/`)**: `app3-main-tokyo` → failover to `app3-main-osaka`
- **Response Path (`/response`)**: `app3-response-tokyo` → failover to `app3-response-osaka`


## Command
### 1. Deploy infrastructure
terraform apply -auto-approve

### 2. Update configs automatically
terraform output -raw monitor_env_yaml > monitor-service/env.yaml
terraform output -raw test_config_yaml > test-config.yaml

### 3. Deploy monitor
cd monitor-service && ./deploy.sh && cd ..

### 4. Check the Cloud Scheduler job
gcloud scheduler jobs describe failover-monitor-job --location=asia-northeast1 --project=my-project-1101-476915

### 5. Check the failover monitor status
curl -s https://auto-failover-monitor-415553820463.asia-northeast2.run.app/status | jq
curl -s https://auto-failover-monitor-415553820463.asia-northeast2.run.app/monitor | jq

### 6. Test
./test-auto-failover.sh

