# Quick Start Guide - Memory Load Generator (Local Testing)

## 🚀 3 Mức Memory Support: 75%, 85%, 99%

### Option 1: Test Local - Single Container

```bash
# Default 85%
docker compose up -d
curl http://localhost:8080/health
docker stats memory-load-test

# Custom target (edit docker-compose.yml)
# environment:
#   - MEMORY_TARGET=75  # hoặc 85, 99

docker compose down
docker compose up -d
```

### Option 2: Test Local - 3 Containers Cùng Lúc

```bash
# Build image một lần
docker compose build --no-cache

# Start cả 3 containers
docker compose -f docker-compose-75.yml up -d  # Port 8075
docker compose -f docker-compose-85.yml up -d  # Port 8085
docker compose -f docker-compose-99.yml up -d  # Port 8099

# Cleanup
docker compose -f docker-compose-75.yml down
docker compose -f docker-compose-85.yml down
docker compose -f docker-compose-99.yml down
```

## 📝 Files

- `memory_load.py` - Core Memory load generator
- `mem_load_with_http.py` - HTTP server wrapper (used by Dockerfile)
- `Dockerfile` - Container definition
- `docker-compose.yml` - Default config (85%)
- `docker-compose-75.yml` - 75% Memory config
- `docker-compose-85.yml` - 85% Memory config
- `docker-compose-99.yml` - 99% Memory config

## 🎯 Next Steps

Sau khi test local thành công, xem file `QUICK_START_CLOUD_RUN.md` để deploy lên GCP Cloud Run.
