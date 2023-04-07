variable "gcp_project_id" {
  type        = string
  description = "The GCP project id."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region where kubeflow will be launched."
}

variable "gcp_zone" {
  type        = string
  description = "The GCP zone where kubeflow will be launched."
}

variable "gcp_credentials" {
  type        = string
  description = "Path to GCP credentials file."
}