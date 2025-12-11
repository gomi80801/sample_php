output "alb1_ip" {
  description = "ALB1 IP Address"
  value       = google_compute_global_address.alb1.address
}

output "alb1_url" {
  description = "ALB1 URL"
  value       = "http://${google_compute_global_address.alb1.address}"
}

# output "alb2_ip" {
#   description = "ALB2 IP Address"
#   value       = google_compute_global_address.alb2.address
# }

# output "alb2_url" {
#   description = "ALB2 URL"
#   value       = "http://${google_compute_global_address.alb2.address}"
# }

# output "alb3_ip" {
#   description = "ALB3 IP Address"
#   value       = google_compute_global_address.alb3.address
# }

# output "alb3_url" {
#   description = "ALB3 URL"
#   value       = "http://${google_compute_global_address.alb3.address}"
# }

# ===================================================================
# Test Config YAML Output
# Copy this output to test-config.yaml after terraform apply
# ===================================================================

output "backend_config_json" {
  description = "BACKEND_CONFIG_JSON for monitor-service env.yaml - copy this to BACKEND_CONFIG_JSON field"
  value = jsonencode({
    "alb1-main-backend-service" = {
      primary_neg   = google_compute_region_network_endpoint_group.alb1_main_tokyo_neg.name
      secondary_neg = google_compute_region_network_endpoint_group.alb1_main_osaka_neg.name
    }
    "alb1-response-backend-service" = {
      primary_neg   = google_compute_region_network_endpoint_group.alb1_response_tokyo_neg.name
      secondary_neg = google_compute_region_network_endpoint_group.alb1_response_osaka_neg.name
    }
    # "alb2-main-backend-service" = {
    #   primary_neg   = google_compute_region_network_endpoint_group.alb2_main_tokyo_neg.name
    #   secondary_neg = google_compute_region_network_endpoint_group.alb2_main_osaka_neg.name
    # }
    # "alb2-response-backend-service" = {
    #   primary_neg   = google_compute_region_network_endpoint_group.alb2_response_tokyo_neg.name
    #   secondary_neg = google_compute_region_network_endpoint_group.alb2_response_osaka_neg.name
    # }
    # "alb3-main-backend-service" = {
    #   primary_neg   = google_compute_region_network_endpoint_group.alb3_main_tokyo_neg.name
    #   secondary_neg = google_compute_region_network_endpoint_group.alb3_main_osaka_neg.name
    # }
    # "alb3-response-backend-service" = {
    #   primary_neg   = google_compute_region_network_endpoint_group.alb3_response_tokyo_neg.name
    #   secondary_neg = google_compute_region_network_endpoint_group.alb3_response_osaka_neg.name
    # }
  })
}

output "monitor_env_yaml" {
  description = "Complete env.yaml content for monitor-service - copy this to monitor-service/env.yaml"
  value = <<-EOT
# Environment Variables Configuration
# Auto-generated from Terraform outputs

# GCP Project ID
PROJECT_ID: ${var.project_id}

# Primary and Secondary Regions
PRIMARY_REGION: ${var.primary_region}
SECONDARY_REGION: ${var.secondary_region}

# Health Check URLs (Cloud Run services)
# Using ALB1 main services for health check
PRIMARY_URL: ${google_cloud_run_v2_service.alb1_main_tokyo.uri}
SECONDARY_URL: ${google_cloud_run_v2_service.alb1_main_osaka.uri}

# Backend Services Configuration (JSON format)
# 6 backend services: 3 ALBs x 2 paths (main + response)
BACKEND_CONFIG_JSON: >-
  {
    "alb1-main-backend-service": {
      "primary_neg": "${google_compute_region_network_endpoint_group.alb1_main_tokyo_neg.name}",
      "secondary_neg": "${google_compute_region_network_endpoint_group.alb1_main_osaka_neg.name}"
    },
    "alb1-response-backend-service": {
      "primary_neg": "${google_compute_region_network_endpoint_group.alb1_response_tokyo_neg.name}",
      "secondary_neg": "${google_compute_region_network_endpoint_group.alb1_response_osaka_neg.name}"
    },

  }
EOT
}

output "test_config_yaml" {
  description = "Complete test-config.yaml content - copy this to test-config.yaml"
  value = <<-EOT
# Test Configuration for Auto-Failover Testing
# This file contains all resource configurations for testing failover across different systems
# Auto-generated from Terraform outputs

# GCP Project ID
project_id: ${var.project_id}

# Monitor Service URL
monitor_url: https://auto-failover-monitor-zocpikyq2a-an.a.run.app

# Primary and Secondary Regions
primary_region: ${var.primary_region}
secondary_region: ${var.secondary_region}

# ALB Configuration
# Format: name|ip|paths (comma-separated)
albs:
  - name: ALB1
    ip: ${google_compute_global_address.alb1.address}
    paths: /,/response

# Backend Services to monitor
backend_services:
  - alb1-main-backend-service
  - alb1-response-backend-service


# Cloud Run Services (Primary Region)
# These are the services that will be deleted during failover testing
primary_services:
  - app1-main-tokyo
  - app1-response-tokyo

EOT
}

# ALB1 Cloud Run URLs
output "alb1_main_tokyo_url" {
  description = "ALB1 Main Tokyo Cloud Run URL"
  value       = google_cloud_run_v2_service.alb1_main_tokyo.uri
}

output "alb1_main_osaka_url" {
  description = "ALB1 Main Osaka Cloud Run URL"
  value       = google_cloud_run_v2_service.alb1_main_osaka.uri
}

output "alb1_response_tokyo_url" {
  description = "ALB1 Response Tokyo Cloud Run URL"
  value       = google_cloud_run_v2_service.alb1_response_tokyo.uri
}

output "alb1_response_osaka_url" {
  description = "ALB1 Response Osaka Cloud Run URL"
  value       = google_cloud_run_v2_service.alb1_response_osaka.uri
}

# # ALB2 Cloud Run URLs
# output "alb2_main_tokyo_url" {
#   description = "ALB2 Main Tokyo Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb2_main_tokyo.uri
# }

# output "alb2_main_osaka_url" {
#   description = "ALB2 Main Osaka Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb2_main_osaka.uri
# }

# output "alb2_response_tokyo_url" {
#   description = "ALB2 Response Tokyo Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb2_response_tokyo.uri
# }

# output "alb2_response_osaka_url" {
#   description = "ALB2 Response Osaka Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb2_response_osaka.uri
# }

# # ALB3 Cloud Run URLs
# output "alb3_main_tokyo_url" {
#   description = "ALB3 Main Tokyo Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb3_main_tokyo.uri
# }

# output "alb3_main_osaka_url" {
#   description = "ALB3 Main Osaka Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb3_main_osaka.uri
# }

# output "alb3_response_tokyo_url" {
#   description = "ALB3 Response Tokyo Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb3_response_tokyo.uri
# }

# output "alb3_response_osaka_url" {
#   description = "ALB3 Response Osaka Cloud Run URL"
#   value       = google_cloud_run_v2_service.alb3_response_osaka.uri
# }

# ===================================================================
# Quick Instructions
# ===================================================================

output "setup_instructions" {
  description = "Complete setup instructions after terraform apply"
  value = <<-EOT

╔════════════════════════════════════════════════════════════════════╗
║              🚀 TERRAFORM APPLY COMPLETED                          ║
╚════════════════════════════════════════════════════════════════════╝

📋 STEP 1: Update test-config.yaml
────────────────────────────────────────────────────────────────────
    terraform output -raw test_config_yaml > test-config.yaml

📋 STEP 2: Update monitor-service/env.yaml
────────────────────────────────────────────────────────────────────
    terraform output -raw monitor_env_yaml > monitor-service/env.yaml

📋 STEP 3: Redeploy monitor service
────────────────────────────────────────────────────────────────────
    cd monitor-service
    ./deploy.sh

📋 STEP 4: Run failover test
────────────────────────────────────────────────────────────────────
    cd ..
    ./test-auto-failover.sh

🌐 ALB URLs:
────────────────────────────────────────────────────────────────────
   • ALB1: http://${google_compute_global_address.alb1.address}

📊 Quick View Outputs:
────────────────────────────────────────────────────────────────────
   • Backend Config JSON:  terraform output backend_config_json
   • Monitor env.yaml:     terraform output monitor_env_yaml
   • Test config.yaml:     terraform output test_config_yaml

✅ All resources deployed successfully!

EOT
}
