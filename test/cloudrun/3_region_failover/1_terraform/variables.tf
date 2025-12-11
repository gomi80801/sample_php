variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "primary_region" {
  description = "Primary region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "secondary_region" {
  description = "Secondary region for failover"
  type        = string
  default     = "asia-northeast2"
}

variable "container_image" {
  description = "Container image to deploy to Cloud Run"
  type        = string
  default     = "gcr.io/cloudrun/hello"
}

# ALB1 Capacity Variables
variable "alb1_main_tokyo_capacity" {
  description = "Capacity scaler for ALB1 Main Tokyo backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 1.0
}

variable "alb1_main_osaka_capacity" {
  description = "Capacity scaler for ALB1 Main Osaka backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 0.0
}

variable "alb1_response_tokyo_capacity" {
  description = "Capacity scaler for ALB1 Response Tokyo backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 1.0
}

variable "alb1_response_osaka_capacity" {
  description = "Capacity scaler for ALB1 Response Osaka backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 0.0
}

# ALB2 Capacity Variables
variable "alb2_main_tokyo_capacity" {
  description = "Capacity scaler for ALB2 Main Tokyo backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 1.0
}

variable "alb2_main_osaka_capacity" {
  description = "Capacity scaler for ALB2 Main Osaka backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 0.0
}

variable "alb2_response_tokyo_capacity" {
  description = "Capacity scaler for ALB2 Response Tokyo backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 1.0
}

variable "alb2_response_osaka_capacity" {
  description = "Capacity scaler for ALB2 Response Osaka backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 0.0
}

# ALB3 Capacity Variables
variable "alb3_main_tokyo_capacity" {
  description = "Capacity scaler for ALB3 Main Tokyo backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 1.0
}

variable "alb3_main_osaka_capacity" {
  description = "Capacity scaler for ALB3 Main Osaka backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 0.0
}

variable "alb3_response_tokyo_capacity" {
  description = "Capacity scaler for ALB3 Response Tokyo backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 1.0
}

variable "alb3_response_osaka_capacity" {
  description = "Capacity scaler for ALB3 Response Osaka backend (0.0 = disabled, 1.0 = full capacity)"
  type        = number
  default     = 0.0
}
