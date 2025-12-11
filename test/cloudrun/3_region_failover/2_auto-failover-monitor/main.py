"""
Auto-Failover Monitor - Cloud Run Service
Monitors primary/secondary Cloud Run health and automatically updates multiple backend services
Fully configurable via environment variables for reusability across different systems
"""

import os
import requests
import logging
from flask import Flask, jsonify
from google.cloud import compute_v1
from google.cloud import run_v2
import json

# ==================== CONFIGURATION FROM ENV VARS ====================
# Core Settings
PROJECT_ID = os.environ.get('PROJECT_ID', 'my-project-1101-476915')
PRIMARY_REGION = os.environ.get('PRIMARY_REGION', 'asia-northeast1')
SECONDARY_REGION = os.environ.get('SECONDARY_REGION', 'asia-northeast2')

CLOUD_RUN_URL_WITH_KNOWN_HASH = os.environ.get('CLOUD_RUN_URL_WITH_KNOWN_HASH', 'zocpikyq2a')

# Backend Services Configuration (JSON format)
# Format: {"backend-service-name": {"primary_neg": "neg-name", "secondary_neg": "neg-name"}}
# Example: {"global-backend-service": {"primary_neg": "tokyo-serverless-neg", "secondary_neg": "osaka-serverless-neg"}}
BACKEND_CONFIG_JSON = os.environ.get('BACKEND_CONFIG_JSON', '')

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==================== PARSE CONFIGURATION ====================
def parse_backend_config():
    """Parse backend configuration from environment variable"""
    if not BACKEND_CONFIG_JSON:
        # Fallback to default config for backward compatibility
        logger.warning("BACKEND_CONFIG_JSON not set, using default configuration")
        return {
            'global-backend-service': {
                'primary_neg': 'tokyo-serverless-neg',
                'secondary_neg': 'osaka-serverless-neg'
            }
        }
    
    try:
        config = json.loads(BACKEND_CONFIG_JSON)
        logger.info(f"Loaded backend configuration for {len(config)} service(s)")
        return config
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse BACKEND_CONFIG_JSON: {e}")
        raise ValueError(f"Invalid BACKEND_CONFIG_JSON format: {e}")

# Build full NEG URLs and Cloud Run service URLs from configuration
RAW_BACKEND_CONFIGS = parse_backend_config()
BACKEND_CONFIGS = {}
BACKEND_SERVICES = []

for backend_name, negs in RAW_BACKEND_CONFIGS.items():
    # Extract Cloud Run service name from NEG name (e.g., "alb1-main-tokyo-neg" -> "app1-main-tokyo")
    primary_neg_name = negs["primary_neg"]
    secondary_neg_name = negs["secondary_neg"]
    
    # Convert NEG name to Cloud Run service name
    # Pattern: alb1-main-tokyo-neg -> app1-main-tokyo
    primary_service_name = primary_neg_name.replace("-neg", "").replace("alb", "app")
    secondary_service_name = secondary_neg_name.replace("-neg", "").replace("alb", "app")
    
    BACKEND_CONFIGS[backend_name] = {
        'primary_neg': f'https://www.googleapis.com/compute/v1/projects/{PROJECT_ID}/regions/{PRIMARY_REGION}/networkEndpointGroups/{negs["primary_neg"]}',
        'secondary_neg': f'https://www.googleapis.com/compute/v1/projects/{PROJECT_ID}/regions/{SECONDARY_REGION}/networkEndpointGroups/{negs["secondary_neg"]}',
        'primary_service': primary_service_name,
        'secondary_service': secondary_service_name
    }
    BACKEND_SERVICES.append(backend_name)

logger.info(f"Configured backend services: {', '.join(BACKEND_SERVICES)}")
logger.info(f"Primary region: {PRIMARY_REGION}, Secondary region: {SECONDARY_REGION}")

def check_service_health(service_name, region):
    """Check if a specific Cloud Run service exists and is ready using Cloud Run API"""
    try:
        # Use Cloud Run API to check service status
        # This works even when services are restricted to ALB-only access
        client = run_v2.ServicesClient()
        
        # Construct service path: projects/{project}/locations/{location}/services/{service}
        service_path = f"projects/{PROJECT_ID}/locations/{region}/services/{service_name}"
        
        logger.info(f"Checking service status via API: {service_path}")
        
        try:
            service = client.get_service(name=service_path)
            
            # Check if service exists
            if not service:
                logger.warning(f"Service {service_name} not found in {region}")
                return False
            
            # Primary method: check terminal_condition (Cloud Run v2 API standard)
            if hasattr(service, 'terminal_condition') and service.terminal_condition:
                condition = service.terminal_condition
                logger.info(f"Terminal condition - type: {condition.type_}, state: {condition.state}, message: {condition.message if hasattr(condition, 'message') else ''}")
                
                # Check if Ready and state is CONDITION_SUCCEEDED
                if condition.type_ == 'Ready' and condition.state == run_v2.Condition.State.CONDITION_SUCCEEDED:
                    logger.info(f"Service {service_name} in {region} is READY (terminal_condition)")
                    return True
                else:
                    logger.warning(f"Service {service_name} in {region} terminal_condition NOT READY - state: {condition.state}")
                    return False
            
            # Fallback: check conditions list for Ready condition
            if hasattr(service, 'conditions') and service.conditions:
                for condition in service.conditions:
                    if condition.type_ == 'Ready':
                        logger.info(f"Conditions - type: {condition.type_}, state: {condition.state}")
                        if condition.state == run_v2.Condition.State.CONDITION_SUCCEEDED:
                            logger.info(f"Service {service_name} in {region} is READY (conditions)")
                            return True
                        else:
                            logger.warning(f"Service {service_name} in {region} NOT READY via conditions - state: {condition.state}")
                            return False
            
            # Last resort: check if service URI exists
            if hasattr(service, 'uri') and service.uri:
                logger.info(f"Service {service_name} in {region} has URI (assuming healthy): {service.uri}")
                return True
            
            logger.warning(f"Service {service_name} in {region} exists but status unclear")
            return False
            
        except Exception as api_error:
            # Service not found or API error
            logger.error(f"Service {service_name} not found or error in {region}: {api_error}")
            return False
        
    except Exception as e:
        logger.error(f"Failed to check service {service_name} in {region}: {e}")
        return False

def get_current_backends(backend_service_name):
    """Get current backend configuration for a specific backend service"""
    try:
        client = compute_v1.BackendServicesClient()
        backend_service = client.get(
            project=PROJECT_ID,
            backend_service=backend_service_name
        )
        
        if not backend_service.backends:
            logger.warning(f"[{backend_service_name}] No backends found!")
            return 'unknown'
        
        # Check which backend exists (assumes only 1 backend per service after failover)
        for backend in backend_service.backends:
            if PRIMARY_REGION in backend.group:
                logger.info(f"[{backend_service_name}] Primary region ({PRIMARY_REGION}) backend active (capacityScaler: {backend.capacity_scaler})")
                return 'primary'
            elif SECONDARY_REGION in backend.group:
                logger.info(f"[{backend_service_name}] Secondary region ({SECONDARY_REGION}) backend active (capacityScaler: {backend.capacity_scaler})")
                return 'secondary'
        
        return 'unknown'
            
    except Exception as e:
        logger.error(f"[{backend_service_name}] Failed to get backends: {e}")
        return 'unknown'

def switch_to_region(backend_service_name, region):
    """Switch backend to specified region by REMOVING the unhealthy backend"""
    try:
        # Get NEG URLs for this backend service
        if backend_service_name not in BACKEND_CONFIGS:
            logger.error(f"[{backend_service_name}] Backend config not found")
            return False
        
        config = BACKEND_CONFIGS[backend_service_name]
        
        client = compute_v1.BackendServicesClient()
        
        # Get current backend service
        backend_service = client.get(
            project=PROJECT_ID,
            backend_service=backend_service_name
        )
        
        # Create backend for the healthy region only
        if region == 'primary':
            logger.info(f"[{backend_service_name}] Keeping ONLY primary region ({PRIMARY_REGION}), removing secondary")
            backend = compute_v1.Backend(
                group=config['primary_neg'],
                balancing_mode='UTILIZATION',
                capacity_scaler=1.0
            )
        elif region == 'secondary':
            logger.info(f"[{backend_service_name}] Keeping ONLY secondary region ({SECONDARY_REGION}), removing primary")
            backend = compute_v1.Backend(
                group=config['secondary_neg'],
                balancing_mode='UTILIZATION',
                capacity_scaler=1.0
            )
        else:
            logger.error(f"[{backend_service_name}] Invalid region: {region}")
            return False
        
        # Update backends with only the healthy region
        backend_service.backends = [backend]
        
        # Update backend service
        operation = client.update(
            project=PROJECT_ID,
            backend_service=backend_service_name,
            backend_service_resource=backend_service
        )
        
        # Wait for operation to complete
        logger.info(f"[{backend_service_name}] Waiting for backend update operation to complete...")
        operation.result(timeout=300)
        
        logger.info(f"[{backend_service_name}] Successfully switched to {region} region (removed other backend)")
        return True
        
    except Exception as e:
        logger.error(f"[{backend_service_name}] Failed to switch to {region}: {e}")
        return False

@app.route('/')
def home():
    """Health endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'auto-failover-monitor'
    })

@app.route('/monitor')
def monitor():
    """Main monitoring endpoint - manages ALL backend services independently"""
    logger.info("=" * 60)
    logger.info(f"Starting independent health check for {len(BACKEND_SERVICES)} backend service(s)...")
    logger.info(f"Backend services: {', '.join(BACKEND_SERVICES)}")
    
    # Process each backend service INDEPENDENTLY
    results = {}
    
    for backend_service in BACKEND_SERVICES:
        backend_service = backend_service.strip()  # Remove whitespace
        logger.info(f"\n--- Processing: {backend_service} ---")
        
        # Get backend configuration
        if backend_service not in BACKEND_CONFIGS:
            logger.error(f"[{backend_service}] Configuration not found in BACKEND_CONFIGS")
            results[backend_service] = {
                'current_active': 'unknown',
                'action': 'ERROR: Configuration not found',
                'primary_healthy': None,
                'secondary_healthy': None
            }
            continue
        
        config = BACKEND_CONFIGS[backend_service]
        primary_service = config['primary_service']
        secondary_service = config['secondary_service']
        
        # Check health for THIS backend's services
        logger.info(f"[{backend_service}] Checking primary service: {primary_service}")
        logger.info(f"[{backend_service}] Checking secondary service: {secondary_service}")
        
        primary_healthy = check_service_health(primary_service, PRIMARY_REGION)
        secondary_healthy = check_service_health(secondary_service, SECONDARY_REGION)
        
        logger.info(f"[{backend_service}] Primary ({primary_service}): {'HEALTHY' if primary_healthy else 'UNHEALTHY'}")
        logger.info(f"[{backend_service}] Secondary ({secondary_service}): {'HEALTHY' if secondary_healthy else 'UNHEALTHY'}")
        
        # Get current active region
        current_active = get_current_backends(backend_service)
        logger.info(f"[{backend_service}] Current active: {current_active}")
        
        action_taken = None
        
        # Decision logic - ONLY applies to THIS backend service
        if primary_healthy and secondary_healthy:
            # Both healthy - prefer primary
            if current_active != 'primary':
                logger.info(f"[{backend_service}] Both healthy - switching to primary region ({PRIMARY_REGION})")
                if switch_to_region(backend_service, 'primary'):
                    action_taken = f"Switched to primary ({PRIMARY_REGION})"
                else:
                    action_taken = "Failed to switch to primary"
            else:
                logger.info(f"[{backend_service}] Both healthy - keeping primary active")
                action_taken = "No change - primary active"
                
        elif not primary_healthy and secondary_healthy:
            # Primary failed - failover to secondary
            if current_active != 'secondary':
                logger.warning(f"[{backend_service}] Primary failed - FAILOVER TO SECONDARY ({SECONDARY_REGION})")
                if switch_to_region(backend_service, 'secondary'):
                    action_taken = f"FAILOVER TO SECONDARY ({SECONDARY_REGION})"
                else:
                    action_taken = "Failed to failover to secondary"
            else:
                logger.info(f"[{backend_service}] Primary still down - keeping secondary active")
                action_taken = "No change - secondary active"
                
        elif primary_healthy and not secondary_healthy:
            # Secondary failed - keep primary
            if current_active != 'primary':
                logger.warning(f"[{backend_service}] Secondary failed - switching to primary ({PRIMARY_REGION})")
                if switch_to_region(backend_service, 'primary'):
                    action_taken = f"Switched to primary ({PRIMARY_REGION})"
                else:
                    action_taken = "Failed to switch to primary"
            else:
                logger.info(f"[{backend_service}] Secondary down - keeping primary active")
                action_taken = "No change - primary active"
        else:
            # Both failed - no change
            logger.critical(f"[{backend_service}] Both regions unhealthy - no change")
            action_taken = "CRITICAL: Both regions unhealthy"
        
        results[backend_service] = {
            'current_active': current_active,
            'action': action_taken,
            'primary_service': primary_service,
            'primary_healthy': primary_healthy,
            'secondary_service': secondary_service,
            'secondary_healthy': secondary_healthy
        }
    
    return jsonify({
        'timestamp': os.popen('date').read().strip(),
        'primary_region': PRIMARY_REGION,
        'secondary_region': SECONDARY_REGION,
        'backend_services': results
    })

@app.route('/status')
def status():
    """Get current status for ALL backend services without making changes"""
    # Get status for all backend services with their individual health checks
    backend_status = {}
    for backend_service in BACKEND_SERVICES:
        backend_service = backend_service.strip()
        
        current_active = get_current_backends(backend_service)
        
        # Get per-backend health if config exists
        health_info = {'current_active': current_active}
        if backend_service in BACKEND_CONFIGS:
            config = BACKEND_CONFIGS[backend_service]
            primary_service = config['primary_service']
            secondary_service = config['secondary_service']
            
            primary_healthy = check_service_health(primary_service, PRIMARY_REGION)
            secondary_healthy = check_service_health(secondary_service, SECONDARY_REGION)
            
            health_info.update({
                'primary_service': primary_service,
                'primary_healthy': primary_healthy,
                'secondary_service': secondary_service,
                'secondary_healthy': secondary_healthy
            })
        
        backend_status[backend_service] = health_info
    
    return jsonify({
        'primary_region': PRIMARY_REGION,
        'secondary_region': SECONDARY_REGION,
        'backend_services': backend_status
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
