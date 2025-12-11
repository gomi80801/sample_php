#!/bin/bash
# Quick test script for Spanner CPU Metric Pusher

set -e

echo "🚀 Spanner CPU Metric Pusher - Quick Test"
echo "=========================================="

# Check if GCP_PROJECT_ID is set
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ Error: GCP_PROJECT_ID not set"
    echo ""
    echo "Usage:"
    echo "  export GCP_PROJECT_ID=your-project-id"
    echo "  ./test.sh"
    exit 1
fi

echo "✅ Project ID: $GCP_PROJECT_ID"

# Set defaults
export SPANNER_INSTANCE_ID=${SPANNER_INSTANCE_ID:-test-instance}
export CPU_PERCENTAGE=${CPU_PERCENTAGE:-75}
export PUSH_INTERVAL=${PUSH_INTERVAL:-5}

echo "✅ Instance ID: $SPANNER_INSTANCE_ID"
echo "✅ CPU Target: $CPU_PERCENTAGE%"
echo "✅ Push Interval: ${PUSH_INTERVAL}s"
echo ""

# Check if dependencies are installed
if ! python3 -c "import google.cloud.monitoring_v3" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip install -q -r requirements.txt
    echo "✅ Dependencies installed"
fi

# Check authentication
echo "🔐 Checking GCP authentication..."
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    echo "❌ Not authenticated. Running: gcloud auth application-default login"
    gcloud auth application-default login
fi
echo "✅ Authenticated"
echo ""

# Run the script
echo "🚀 Starting metric pusher (Press Ctrl+C to stop)..."
echo ""
python3 push_cpu_metric.py
