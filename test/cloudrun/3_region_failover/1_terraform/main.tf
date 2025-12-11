terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Remote state in GCS - shared across local and Cloud Shell
  backend "gcs" {
    bucket = "my-project-1101-476915-terraform-state"
    prefix = "region-failover"
  }
}

provider "google" {
  project = var.project_id
  region  = var.primary_region
}

# =============================================================================
# ALB1 - Cloud Run Services (app1-main, app1-response)
# =============================================================================

# ALB1 Main - Tokyo
resource "google_cloud_run_v2_service" "alb1_main_tokyo" {
  name     = "app1-main-tokyo"
  location = "asia-northeast1"
  
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  
  template {
    containers {
      image = var.container_image
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
}

# ALB1 Main - Osaka
resource "google_cloud_run_v2_service" "alb1_main_osaka" {
  name     = "app1-main-osaka"
  location = "asia-northeast2"
  
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  
  template {
    containers {
      image = var.container_image
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
}

# ALB1 Response - Tokyo
resource "google_cloud_run_v2_service" "alb1_response_tokyo" {
  name     = "app1-response-tokyo"
  location = "asia-northeast1"
  
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  
  template {
    containers {
      image = var.container_image
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
}

# ALB1 Response - Osaka
resource "google_cloud_run_v2_service" "alb1_response_osaka" {
  name     = "app1-response-osaka"
  location = "asia-northeast2"
  
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  
  template {
    containers {
      image = var.container_image
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
}

# IAM for ALB1 services - Load Balancer access only
# Grant Cloud Run Invoker role to all authenticated users (for Load Balancer)
resource "google_cloud_run_v2_service_iam_member" "alb1_main_tokyo_lb" {
  name     = google_cloud_run_v2_service.alb1_main_tokyo.name
  location = google_cloud_run_v2_service.alb1_main_tokyo.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "alb1_main_osaka_lb" {
  name     = google_cloud_run_v2_service.alb1_main_osaka.name
  location = google_cloud_run_v2_service.alb1_main_osaka.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "alb1_response_tokyo_lb" {
  name     = google_cloud_run_v2_service.alb1_response_tokyo.name
  location = google_cloud_run_v2_service.alb1_response_tokyo.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "alb1_response_osaka_lb" {
  name     = google_cloud_run_v2_service.alb1_response_osaka.name
  location = google_cloud_run_v2_service.alb1_response_osaka.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# =============================================================================
# ALB2 - Cloud Run Services (app2-main, app2-response) - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# # ALB2 Main - Tokyo
# resource "google_cloud_run_v2_service" "alb2_main_tokyo" {
#   name     = "app2-main-tokyo"
#   location = "asia-northeast1"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # ALB2 Main - Osaka
# resource "google_cloud_run_v2_service" "alb2_main_osaka" {
#   name     = "app2-main-osaka"
#   location = "asia-northeast2"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # ALB2 Response - Tokyo
# resource "google_cloud_run_v2_service" "alb2_response_tokyo" {
#   name     = "app2-response-tokyo"
#   location = "asia-northeast1"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # ALB2 Response - Osaka
# resource "google_cloud_run_v2_service" "alb2_response_osaka" {
#   name     = "app2-response-osaka"
#   location = "asia-northeast2"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # IAM for ALB2 services - Load Balancer access only
# resource "google_cloud_run_v2_service_iam_member" "alb2_main_tokyo_lb" {
#   name     = google_cloud_run_v2_service.alb2_main_tokyo.name
#   location = google_cloud_run_v2_service.alb2_main_tokyo.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# resource "google_cloud_run_v2_service_iam_member" "alb2_main_osaka_lb" {
#   name     = google_cloud_run_v2_service.alb2_main_osaka.name
#   location = google_cloud_run_v2_service.alb2_main_osaka.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# resource "google_cloud_run_v2_service_iam_member" "alb2_response_tokyo_lb" {
#   name     = google_cloud_run_v2_service.alb2_response_tokyo.name
#   location = google_cloud_run_v2_service.alb2_response_tokyo.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# resource "google_cloud_run_v2_service_iam_member" "alb2_response_osaka_lb" {
#   name     = google_cloud_run_v2_service.alb2_response_osaka.name
#   location = google_cloud_run_v2_service.alb2_response_osaka.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# =============================================================================
# ALB3 - Cloud Run Services (app3-main, app3-response) - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# # ALB3 Main - Tokyo
# resource "google_cloud_run_v2_service" "alb3_main_tokyo" {
#   name     = "app3-main-tokyo"
#   location = "asia-northeast1"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # ALB3 Main - Osaka
# resource "google_cloud_run_v2_service" "alb3_main_osaka" {
#   name     = "app3-main-osaka"
#   location = "asia-northeast2"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # ALB3 Response - Tokyo
# resource "google_cloud_run_v2_service" "alb3_response_tokyo" {
#   name     = "app3-response-tokyo"
#   location = "asia-northeast1"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # ALB3 Response - Osaka
# resource "google_cloud_run_v2_service" "alb3_response_osaka" {
#   name     = "app3-response-osaka"
#   location = "asia-northeast2"
#   
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   
#   template {
#     containers {
#       image = var.container_image
#       
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#     }
#     
#     scaling {
#       min_instance_count = 0
#       max_instance_count = 10
#     }
#   }
# }

# # IAM for ALB3 services - Load Balancer access only
# resource "google_cloud_run_v2_service_iam_member" "alb3_main_tokyo_lb" {
#   name     = google_cloud_run_v2_service.alb3_main_tokyo.name
#   location = google_cloud_run_v2_service.alb3_main_tokyo.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# resource "google_cloud_run_v2_service_iam_member" "alb3_main_osaka_lb" {
#   name     = google_cloud_run_v2_service.alb3_main_osaka.name
#   location = google_cloud_run_v2_service.alb3_main_osaka.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# resource "google_cloud_run_v2_service_iam_member" "alb3_response_tokyo_lb" {
#   name     = google_cloud_run_v2_service.alb3_response_tokyo.name
#   location = google_cloud_run_v2_service.alb3_response_tokyo.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# resource "google_cloud_run_v2_service_iam_member" "alb3_response_osaka_lb" {
#   name     = google_cloud_run_v2_service.alb3_response_osaka.name
#   location = google_cloud_run_v2_service.alb3_response_osaka.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }

# =============================================================================
# Serverless NEGs for ALB1
# =============================================================================

resource "google_compute_region_network_endpoint_group" "alb1_main_tokyo_neg" {
  name                  = "alb1-main-tokyo-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast1"
  
  cloud_run {
    service = google_cloud_run_v2_service.alb1_main_tokyo.name
  }
}

resource "google_compute_region_network_endpoint_group" "alb1_main_osaka_neg" {
  name                  = "alb1-main-osaka-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast2"
  
  cloud_run {
    service = google_cloud_run_v2_service.alb1_main_osaka.name
  }
}

resource "google_compute_region_network_endpoint_group" "alb1_response_tokyo_neg" {
  name                  = "alb1-response-tokyo-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast1"
  
  cloud_run {
    service = google_cloud_run_v2_service.alb1_response_tokyo.name
  }
}

resource "google_compute_region_network_endpoint_group" "alb1_response_osaka_neg" {
  name                  = "alb1-response-osaka-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast2"
  
  cloud_run {
    service = google_cloud_run_v2_service.alb1_response_osaka.name
  }
}

# =============================================================================
# Serverless NEGs for ALB2 - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# resource "google_compute_region_network_endpoint_group" "alb2_main_tokyo_neg" {
#   name                  = "alb2-main-tokyo-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast1"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb2_main_tokyo.name
#   }
# }

# resource "google_compute_region_network_endpoint_group" "alb2_main_osaka_neg" {
#   name                  = "alb2-main-osaka-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast2"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb2_main_osaka.name
#   }
# }

# resource "google_compute_region_network_endpoint_group" "alb2_response_tokyo_neg" {
#   name                  = "alb2-response-tokyo-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast1"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb2_response_tokyo.name
#   }
# }

# resource "google_compute_region_network_endpoint_group" "alb2_response_osaka_neg" {
#   name                  = "alb2-response-osaka-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast2"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb2_response_osaka.name
#   }
# }

# =============================================================================
# Serverless NEGs for ALB3 - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# resource "google_compute_region_network_endpoint_group" "alb3_main_tokyo_neg" {
#   name                  = "alb3-main-tokyo-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast1"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb3_main_tokyo.name
#   }
# }

# resource "google_compute_region_network_endpoint_group" "alb3_main_osaka_neg" {
#   name                  = "alb3-main-osaka-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast2"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb3_main_osaka.name
#   }
# }

# resource "google_compute_region_network_endpoint_group" "alb3_response_tokyo_neg" {
#   name                  = "alb3-response-tokyo-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast1"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb3_response_tokyo.name
#   }
# }

# resource "google_compute_region_network_endpoint_group" "alb3_response_osaka_neg" {
#   name                  = "alb3-response-osaka-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = "asia-northeast2"
#   
#   cloud_run {
#     service = google_cloud_run_v2_service.alb3_response_osaka.name
#   }
# }

# =============================================================================
# Backend Services for ALB1
# =============================================================================

# Backend Service for ALB1 Main (/ path)
resource "google_compute_backend_service" "alb1_main_backend" {
  name                  = "alb1-main-backend-service"
  protocol              = "HTTPS"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  dynamic "backend" {
    for_each = var.alb1_main_tokyo_capacity > 0 ? [1] : []
    content {
      group           = google_compute_region_network_endpoint_group.alb1_main_tokyo_neg.id
      balancing_mode  = "UTILIZATION"
      capacity_scaler = var.alb1_main_tokyo_capacity
    }
  }

  dynamic "backend" {
    for_each = var.alb1_main_osaka_capacity > 0 ? [1] : []
    content {
      group           = google_compute_region_network_endpoint_group.alb1_main_osaka_neg.id
      balancing_mode  = "UTILIZATION"
      capacity_scaler = var.alb1_main_osaka_capacity
    }
  }
}

# Backend Service for ALB1 Response (/response path)
resource "google_compute_backend_service" "alb1_response_backend" {
  name                  = "alb1-response-backend-service"
  protocol              = "HTTPS"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  dynamic "backend" {
    for_each = var.alb1_response_tokyo_capacity > 0 ? [1] : []
    content {
      group           = google_compute_region_network_endpoint_group.alb1_response_tokyo_neg.id
      balancing_mode  = "UTILIZATION"
      capacity_scaler = var.alb1_response_tokyo_capacity
    }
  }

  dynamic "backend" {
    for_each = var.alb1_response_osaka_capacity > 0 ? [1] : []
    content {
      group           = google_compute_region_network_endpoint_group.alb1_response_osaka_neg.id
      balancing_mode  = "UTILIZATION"
      capacity_scaler = var.alb1_response_osaka_capacity
    }
  }
}

# =============================================================================
# Backend Services for ALB2 - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# # Backend Service for ALB2 Main (/ path)
# resource "google_compute_backend_service" "alb2_main_backend" {
#   name                  = "alb2-main-backend-service"
#   protocol              = "HTTPS"
#   port_name             = "http"
#   timeout_sec           = 30
#   load_balancing_scheme = "EXTERNAL_MANAGED"

#   dynamic "backend" {
#     for_each = var.alb2_main_tokyo_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb2_main_tokyo_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb2_main_tokyo_capacity
#     }
#   }

#   dynamic "backend" {
#     for_each = var.alb2_main_osaka_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb2_main_osaka_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb2_main_osaka_capacity
#     }
#   }
# }

# # Backend Service for ALB2 Response (/response path)
# resource "google_compute_backend_service" "alb2_response_backend" {
#   name                  = "alb2-response-backend-service"
#   protocol              = "HTTPS"
#   port_name             = "http"
#   timeout_sec           = 30
#   load_balancing_scheme = "EXTERNAL_MANAGED"

#   dynamic "backend" {
#     for_each = var.alb2_response_tokyo_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb2_response_tokyo_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb2_response_tokyo_capacity
#     }
#   }

#   dynamic "backend" {
#     for_each = var.alb2_response_osaka_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb2_response_osaka_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb2_response_osaka_capacity
#     }
#   }
# }

# =============================================================================
# Backend Services for ALB3 - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# # Backend Service for ALB3 Main (/ path)
# resource "google_compute_backend_service" "alb3_main_backend" {
#   name                  = "alb3-main-backend-service"
#   protocol              = "HTTPS"
#   port_name             = "http"
#   timeout_sec           = 30
#   load_balancing_scheme = "EXTERNAL_MANAGED"

#   dynamic "backend" {
#     for_each = var.alb3_main_tokyo_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb3_main_tokyo_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb3_main_tokyo_capacity
#     }
#   }

#   dynamic "backend" {
#     for_each = var.alb3_main_osaka_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb3_main_osaka_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb3_main_osaka_capacity
#     }
#   }
# }

# # Backend Service for ALB3 Response (/response path)
# resource "google_compute_backend_service" "alb3_response_backend" {
#   name                  = "alb3-response-backend-service"
#   protocol              = "HTTPS"
#   port_name             = "http"
#   timeout_sec           = 30
#   load_balancing_scheme = "EXTERNAL_MANAGED"

#   dynamic "backend" {
#     for_each = var.alb3_response_tokyo_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb3_response_tokyo_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb3_response_tokyo_capacity
#     }
#   }

#   dynamic "backend" {
#     for_each = var.alb3_response_osaka_capacity > 0 ? [1] : []
#     content {
#       group           = google_compute_region_network_endpoint_group.alb3_response_osaka_neg.id
#       balancing_mode  = "UTILIZATION"
#       capacity_scaler = var.alb3_response_osaka_capacity
#     }
#   }
# }

# =============================================================================
# URL Map for ALB1
# =============================================================================

resource "google_compute_url_map" "alb1" {
  name            = "alb1-url-map"
  default_service = google_compute_backend_service.alb1_main_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "alb1-paths"
  }

  path_matcher {
    name            = "alb1-paths"
    default_service = google_compute_backend_service.alb1_main_backend.id

    path_rule {
      paths   = ["/response", "/response/*"]
      service = google_compute_backend_service.alb1_response_backend.id
    }
  }
}

# =============================================================================
# URL Map for ALB2 - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# resource "google_compute_url_map" "alb2" {
#   name            = "alb2-url-map"
#   default_service = google_compute_backend_service.alb2_main_backend.id

#   host_rule {
#     hosts        = ["*"]
#     path_matcher = "alb2-paths"
#   }

#   path_matcher {
#     name            = "alb2-paths"
#     default_service = google_compute_backend_service.alb2_main_backend.id

#     path_rule {
#       paths   = ["/response", "/response/*"]
#       service = google_compute_backend_service.alb2_response_backend.id
#     }
#   }
# }

# =============================================================================
# URL Map for ALB3 - COMMENTED OUT TO SAVE COSTS
# =============================================================================

# resource "google_compute_url_map" "alb3" {
#   name            = "alb3-url-map"
#   default_service = google_compute_backend_service.alb3_main_backend.id

#   host_rule {
#     hosts        = ["*"]
#     path_matcher = "alb3-paths"
#   }

#   path_matcher {
#     name            = "alb3-paths"
#     default_service = google_compute_backend_service.alb3_main_backend.id

#     path_rule {
#       paths   = ["/response", "/response/*"]
#       service = google_compute_backend_service.alb3_response_backend.id
#     }
#   }
# }

# =============================================================================
# SSL Certificates (Google-managed)
# =============================================================================

resource "google_compute_managed_ssl_certificate" "alb1" {
  name = "alb1-ssl-cert"

  managed {
    domains = ["test.nhameo.site"]
  }
}

# =============================================================================
# Target HTTP Proxies
# =============================================================================

resource "google_compute_target_http_proxy" "alb1" {
  name    = "alb1-http-proxy"
  url_map = google_compute_url_map.alb1.id
}

# resource "google_compute_target_http_proxy" "alb2" {
#   name    = "alb2-http-proxy"
#   url_map = google_compute_url_map.alb2.id
# }

# resource "google_compute_target_http_proxy" "alb3" {
#   name    = "alb3-http-proxy"
#   url_map = google_compute_url_map.alb3.id
# }

# =============================================================================
# Target HTTPS Proxies
# =============================================================================

resource "google_compute_target_https_proxy" "alb1" {
  name             = "alb1-https-proxy"
  url_map          = google_compute_url_map.alb1.id
  ssl_certificates = [google_compute_managed_ssl_certificate.alb1.id]
}

# =============================================================================
# Global IP Addresses
# =============================================================================

resource "google_compute_global_address" "alb1" {
  name = "alb1-ip"
}

# resource "google_compute_global_address" "alb2" {
#   name = "alb2-ip"
# }

# resource "google_compute_global_address" "alb3" {
#   name = "alb3-ip"
# }

# =============================================================================
# Global Forwarding Rules
# =============================================================================

resource "google_compute_global_forwarding_rule" "alb1" {
  name                  = "alb1-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.alb1.id
  ip_address            = google_compute_global_address.alb1.id
}

resource "google_compute_global_forwarding_rule" "alb1_https" {
  name                  = "alb1-https-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.alb1.id
  ip_address            = google_compute_global_address.alb1.id
}

# resource "google_compute_global_forwarding_rule" "alb2" {
#   name                  = "alb2-forwarding-rule"
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   port_range            = "80"
#   target                = google_compute_target_http_proxy.alb2.id
#   ip_address            = google_compute_global_address.alb2.id
# }

# resource "google_compute_global_forwarding_rule" "alb3" {
#   name                  = "alb3-forwarding-rule"
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   port_range            = "80"
#   target                = google_compute_target_http_proxy.alb3.id
#   ip_address            = google_compute_global_address.alb3.id
# }
