#!/bin/bash

# Test Auto-Failover Monitor - Multi Backend Services with ALBs
# This script tests automatic failover for multiple backend services with different ALBs
# Configuration is loaded from test-config.yaml for reusability

CONFIG_FILE="test-config.yaml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo "Please create $CONFIG_FILE from test-config.example.yaml"
  exit 1
fi

# Function to parse YAML (simple parser for flat values)
parse_yaml() {
  local prefix=$2
  local s='[[:space:]]*'
  local w='[a-zA-Z0-9_]*'
  local fs=$(echo @|tr @ '\034')
  sed -ne "s|^\($s\):|\1|" \
       -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
       -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $1 |
  awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
      vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
      printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
  }'
}

# Load configuration
echo "Loading configuration from $CONFIG_FILE..."
eval $(parse_yaml $CONFIG_FILE "config_")

PROJECT_ID="$config_project_id"
MONITOR_URL="$config_monitor_url"
PRIMARY_REGION="$config_primary_region"
SECONDARY_REGION="$config_secondary_region"

# Generate friendly region names for display
if [[ "$PRIMARY_REGION" == *"northeast1" ]]; then
  PRIMARY_DISPLAY="Tokyo ($PRIMARY_REGION)"
  SECONDARY_DISPLAY="Osaka ($SECONDARY_REGION)"
elif [[ "$PRIMARY_REGION" == *"northeast2" ]]; then
  PRIMARY_DISPLAY="Osaka ($PRIMARY_REGION)"
  SECONDARY_DISPLAY="Tokyo ($SECONDARY_REGION)"
elif [[ "$PRIMARY_REGION" == *"central1" ]]; then
  PRIMARY_DISPLAY="US-Central ($PRIMARY_REGION)"
  SECONDARY_DISPLAY="US-East ($SECONDARY_REGION)"
else
  PRIMARY_DISPLAY="$PRIMARY_REGION"
  SECONDARY_DISPLAY="$SECONDARY_REGION"
fi

# Parse ALBs from YAML (using indexed arrays for macOS bash compatibility)
ALB_NAMES=()
ALB_IPS=()
ALB_PATHS=()
while IFS= read -r line; do
  if [[ $line =~ ^[[:space:]]*-[[:space:]]*name: ]]; then
    alb_name=$(echo "$line" | sed 's/.*name:[[:space:]]*\(.*\)/\1/')
    read -r ip_line
    alb_ip=$(echo "$ip_line" | sed 's/.*ip:[[:space:]]*\(.*\)/\1/')
    read -r paths_line
    alb_paths=$(echo "$paths_line" | sed 's/.*paths:[[:space:]]*\(.*\)/\1/' | tr ',' ' ')
    
    ALB_NAMES+=("$alb_name")
    ALB_IPS+=("$alb_ip")
    ALB_PATHS+=("$alb_paths")
  fi
done < <(sed -n '/^albs:/,/^[a-z]/p' $CONFIG_FILE | grep -v '^[a-z]' | grep -v '^$')

# Parse backend services
BACKENDS=()
while IFS= read -r line; do
  if [[ $line =~ ^[[:space:]]*-[[:space:]]* ]]; then
    backend=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
    BACKENDS+=("$backend")
  fi
done < <(sed -n '/^backend_services:/,/^[a-z]/p' $CONFIG_FILE | grep '  -')

# Parse primary services
PRIMARY_SERVICES=()
while IFS= read -r line; do
  if [[ $line =~ ^[[:space:]]*-[[:space:]]* ]]; then
    service=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
    PRIMARY_SERVICES+=("$service")
  fi
done < <(sed -n '/^primary_services:/,/^[a-z]/p' $CONFIG_FILE | grep '  -')

echo "✓ Configuration loaded:"
echo "  Project: $PROJECT_ID"
echo "  Monitor: $MONITOR_URL"
echo "  Primary Region: $PRIMARY_REGION"
echo "  Secondary Region: $SECONDARY_REGION"
echo "  ALBs: ${ALB_NAMES[@]}"
echo "  Backend Services: ${#BACKENDS[@]}"
echo "  Primary Services: ${#PRIMARY_SERVICES[@]}"
echo ""

echo "=========================================="
echo "Auto-Failover Test - Multiple Backends"
echo "=========================================="
echo ""

# Step 1: Check current status
echo "Step 1: Current Status (All Backend Services)"
echo "----------------------------------------------"
STATUS_CHECK=$(curl -s -w "\nHTTP_CODE:%{http_code}" $MONITOR_URL/status 2>&1)
HTTP_CODE_CHECK=$(echo "$STATUS_CHECK" | grep "HTTP_CODE:" | cut -d: -f2)
STATUS_BODY_CHECK=$(echo "$STATUS_CHECK" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE_CHECK" = "200" ] && echo "$STATUS_BODY_CHECK" | jq -e . >/dev/null 2>&1; then
  echo "$STATUS_BODY_CHECK" | jq '.'
else
  echo "⚠ Warning: Monitor service returned HTTP $HTTP_CODE_CHECK"
  echo "Response: $STATUS_BODY_CHECK"
  echo ""
  echo "Possible issues:"
  echo "  - Monitor service not deployed yet"
  echo "  - Wrong MONITOR_URL in test-config.yaml"
  echo "  - Service authentication required"
  echo ""
  read -p "Continue anyway? (y/n): " continue_test
  if [ "$continue_test" != "y" ]; then
    echo "Test aborted."
    exit 1
  fi
fi
echo ""

# Step 2: Verify backend health via Monitor Service API
echo "Step 2: Verify Backend Health via Monitor Service API"
echo "-------------------------------------------------------"
echo "Note: Cloud Run services are restricted to Load Balancer access only"
echo "      Cannot test via direct HTTP requests (would return 403)"
echo "      Using Monitor Service API to verify backend health status"
echo ""

STATUS_BEFORE=$(curl -s $MONITOR_URL/status)
if echo "$STATUS_BEFORE" | jq -e . >/dev/null 2>&1; then
  echo "Current backend health status:"
  echo "$STATUS_BEFORE" | jq '.backend_services | to_entries[] | {backend: .key, current_active: .value.current_active, primary_healthy: .value.primary_healthy, secondary_healthy: .value.secondary_healthy}'
  echo ""
  
  # Count healthy backends
  PRIMARY_HEALTHY=$(echo "$STATUS_BEFORE" | jq '[.backend_services[] | select(.primary_healthy == true)] | length')
  SECONDARY_HEALTHY=$(echo "$STATUS_BEFORE" | jq '[.backend_services[] | select(.secondary_healthy == true)] | length')
  TOTAL_BACKENDS=$(echo "$STATUS_BEFORE" | jq '.backend_services | length')
  
  echo "Summary:"
  echo "  Total backends: $TOTAL_BACKENDS"
  echo "  Primary region healthy: $PRIMARY_HEALTHY/$TOTAL_BACKENDS"
  echo "  Secondary region healthy: $SECONDARY_HEALTHY/$TOTAL_BACKENDS"
  echo "  ✓ All backends verified via API (HTTP requests skipped due to ingress restrictions)"
else
  echo "⚠ Warning: Could not get backend status from monitor service"
fi
echo ""

# Step 3: Select services to delete
echo "Step 3: Select $PRIMARY_DISPLAY Services to Delete"
echo "-------------------------------------------------------------------"
echo "Available services in $PRIMARY_DISPLAY:"
for i in "${!PRIMARY_SERVICES[@]}"; do
  echo "  $((i+1))) ${PRIMARY_SERVICES[$i]}"
done
echo ""
echo "Choose deletion mode:"
echo "  1) Delete ALL services in $PRIMARY_DISPLAY (${#PRIMARY_SERVICES[@]} services)"
echo "  2) Select specific services to delete"
echo ""
read -p "Enter your choice (1 or 2): " DELETE_MODE

SERVICES_TO_DELETE=()

if [ "$DELETE_MODE" = "1" ]; then
  # Delete all services
  SERVICES_TO_DELETE=("${PRIMARY_SERVICES[@]}")
  echo ""
  echo "Selected: ALL services in $PRIMARY_DISPLAY (${#SERVICES_TO_DELETE[@]} services)"
  
elif [ "$DELETE_MODE" = "2" ]; then
  # Interactive selection
  echo ""
  echo "Select services to delete (y/n for each):"
  
  for service in "${PRIMARY_SERVICES[@]}"; do
    read -p "  Delete $service? (y/n): " ans
    [ "$ans" = "y" ] && SERVICES_TO_DELETE+=("$service")
  done
  
  echo ""
  echo "Selected services: ${SERVICES_TO_DELETE[@]}"
  
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Confirm deletion
echo ""
read -p "Press Enter to delete selected Cloud Run service(s) in $PRIMARY_DISPLAY and test auto-failover..."

# Delete selected services in parallel
echo ""
echo "Deleting selected services in $PRIMARY_DISPLAY in parallel..."
for service in "${SERVICES_TO_DELETE[@]}"; do
  echo "  → Deleting $service..."
  gcloud run services delete $service --region=$PRIMARY_REGION --project=$PROJECT_ID --quiet &
done
wait

echo ""
echo "✅ Selected services in $PRIMARY_DISPLAY deleted! Waiting for auto-failover..."
echo ""

# Determine which backend services should failover based on deleted Cloud Run services
AFFECTED_BACKENDS=()
for service in "${SERVICES_TO_DELETE[@]}"; do
  # Map Cloud Run service to backend service
  # Pattern: app1-main-tokyo -> alb1-main-backend-service
  # Pattern: app2-response-tokyo -> alb2-response-backend-service
  
  # Extract alb number and path type (main or response)
  if [[ $service =~ app([0-9]+)-(main|response)- ]]; then
    alb_num="${BASH_REMATCH[1]}"
    path_type="${BASH_REMATCH[2]}"
    backend="alb${alb_num}-${path_type}-backend-service"
    
    # Add to affected backends if not already in list
    if [[ ! " ${AFFECTED_BACKENDS[@]} " =~ " ${backend} " ]]; then
      AFFECTED_BACKENDS+=("$backend")
    fi
  fi
done

echo ""
echo "Expected affected backend services (${#AFFECTED_BACKENDS[@]}):"
for backend in "${AFFECTED_BACKENDS[@]}"; do
  echo "  - $backend"
done
echo ""

# Step 4: Wait for monitor to detect and failover (max 2 minutes)
echo "Step 4: Monitoring failover process (Affected Backend Services Only)"
echo "---------------------------------------------------------------------"
echo "Cloud Scheduler runs every minute, so failover will happen within 1-2 minutes..."
echo ""

FAILOVER_COMPLETE=false
for i in {1..30}; do
  echo "Check $i/30 (every 10 seconds):"
  
  # Get status with error handling
  STATUS=$(curl -s -w "\nHTTP_CODE:%{http_code}" $MONITOR_URL/status 2>&1)
  HTTP_CODE=$(echo "$STATUS" | grep "HTTP_CODE:" | cut -d: -f2)
  STATUS_BODY=$(echo "$STATUS" | grep -v "HTTP_CODE:")
  
  # Check if response is valid
  if [ "$HTTP_CODE" != "200" ] || ! echo "$STATUS_BODY" | jq -e . >/dev/null 2>&1; then
    echo "  ⚠ Monitor service not responding properly (HTTP $HTTP_CODE)"
    echo "  Response: $STATUS_BODY"
    echo "  Retrying..."
    sleep 10
    continue
  fi
  
  # Display formatted JSON
  echo "$STATUS_BODY" | jq '.'
  
  # Count how many affected backends have failed over to Secondary
  SECONDARY_COUNT=0
  for backend in "${AFFECTED_BACKENDS[@]}"; do
    CURRENT=$(echo "$STATUS_BODY" | jq -r ".backend_services.\"$backend\".current_active" 2>/dev/null)
    echo "  → $backend: $CURRENT"
    if [ "$CURRENT" = "secondary" ]; then
      SECONDARY_COUNT=$((SECONDARY_COUNT + 1))
    fi
  done
  
  echo "  Failover progress: $SECONDARY_COUNT/${#AFFECTED_BACKENDS[@]} backend services"
  
  # Check if ALL affected backends have failed over
  if [ $SECONDARY_COUNT -eq ${#AFFECTED_BACKENDS[@]} ]; then
    echo ""
    echo "✓ Failover detected! All ${#AFFECTED_BACKENDS[@]} affected backend(s) now pointing to $SECONDARY_DISPLAY"
    FAILOVER_COMPLETE=true
    break
  fi
  
  echo "  Waiting for remaining backends to failover..."
  sleep 10
done

if [ "$FAILOVER_COMPLETE" = false ]; then
  echo ""
  echo "⚠ Failover not completed within expected time. Continuing test..."
fi

echo ""
echo "Step 5: Waiting for config to propagate (30 seconds)"
echo "-----------------------------------------------------"
sleep 30

# Step 6: Verify backends after failover via Monitor Service API
echo ""
echo "Step 6: Verify Backends After Failover via Monitor Service API"
echo "----------------------------------------------------------------"
echo "Note: Cloud Run services are restricted to Load Balancer access only"
echo "      Verifying failover status through Monitor Service API"
echo ""

STATUS_AFTER=$(curl -s $MONITOR_URL/status)
if echo "$STATUS_AFTER" | jq -e . >/dev/null 2>&1; then
  echo "Backend status after failover:"
  echo "$STATUS_AFTER" | jq '.backend_services | to_entries[] | {backend: .key, current_active: .value.current_active, primary_healthy: .value.primary_healthy, secondary_healthy: .value.secondary_healthy}'
  echo ""
  
  # Check affected backends
  echo "Verifying affected backends have failed over to $SECONDARY_DISPLAY:"
  FAILOVER_SUCCESS_COUNT=0
  for backend in "${AFFECTED_BACKENDS[@]}"; do
    CURRENT=$(echo "$STATUS_AFTER" | jq -r ".backend_services.\"$backend\".current_active" 2>/dev/null)
    PRIMARY_H=$(echo "$STATUS_AFTER" | jq -r ".backend_services.\"$backend\".primary_healthy" 2>/dev/null)
    SECONDARY_H=$(echo "$STATUS_AFTER" | jq -r ".backend_services.\"$backend\".secondary_healthy" 2>/dev/null)
    
    if [ "$CURRENT" = "secondary" ] && [ "$SECONDARY_H" = "true" ]; then
      echo "  ✓ $backend: Successfully failed over to secondary (healthy: $SECONDARY_H)"
      FAILOVER_SUCCESS_COUNT=$((FAILOVER_SUCCESS_COUNT + 1))
    elif [ "$CURRENT" = "primary" ] && [ "$PRIMARY_H" = "false" ]; then
      echo "  ✗ $backend: Still on primary but primary is unhealthy!"
    else
      echo "  ⚠ $backend: Current=$CURRENT, Primary=$PRIMARY_H, Secondary=$SECONDARY_H"
    fi
  done
  
  echo ""
  echo "Failover Summary: $FAILOVER_SUCCESS_COUNT/${#AFFECTED_BACKENDS[@]} backends successfully failed over"
else
  echo "⚠ Warning: Could not get backend status from monitor service"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "Deleted Cloud Run services (${#SERVICES_TO_DELETE[@]}):"
for service in "${SERVICES_TO_DELETE[@]}"; do
  echo "  ✗ $service (in $PRIMARY_DISPLAY)"
done
echo ""
echo "Expected affected backend services (${#AFFECTED_BACKENDS[@]}):"
for backend in "${AFFECTED_BACKENDS[@]}"; do
  echo "  → $backend (should be secondary)"
done
echo ""
echo "Final status of all backend services:"
curl -s $MONITOR_URL/status | jq '.backend_services'
echo ""
echo "Test Complete!"
echo "=========================================="
echo ""