terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.gcp_credentials)
  project     = var.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}

resource "google_project_service" "cloud_resource_manager" {
  service = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "iap" {
  service = "iap.googleapis.com"
  disable_dependent_services = true
  depends_on = [google_project_service.cloud_resource_manager]
}

resource "google_project_service" "compute_engine" {
  service = "compute.googleapis.com"
  disable_dependent_services = true
  depends_on = [google_project_service.cloud_resource_manager]
}

resource "google_project_service" "kubernetes_engine" {
  service = "container.googleapis.com"
  disable_dependent_services = true
  depends_on = [google_project_service.cloud_resource_manager]
}

resource "google_storage_bucket" "kubeflow_storage" {
  name          = format("kubeflow-%s", var.gcp_project_id)
  location      = var.gcp_region
  force_destroy = true
  public_access_prevention = "enforced"
  depends_on = [google_project_service.cloud_resource_manager]
}

resource "google_container_cluster" "kubeflow_cluster" {
  name               = "my-kubeflow-cluster"
  initial_node_count = 2

  node_config {
    machine_type = "n2-standard-2"
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  depends_on = [google_project_service.compute_engine, google_project_service.kubernetes_engine]
}

resource "null_resource" "kubectl_access" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials $CLUSTER_NAME --region=$COMPUTE_REGION"
    environment = {
      "CLUSTER_NAME" = google_container_cluster.kubeflow_cluster.name
      "COMPUTE_REGION" = var.gcp_zone
    }
  }
  depends_on = [google_container_cluster.kubeflow_cluster]
}

resource "null_resource" "kubeflow-pipelines" {
  provisioner "local-exec" {
    command = "kubectl apply -k \"github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=$PIPELINE_VERSION\" && kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io && kubectl apply -k \"github.com/kubeflow/pipelines/manifests/kustomize/env/dev?ref=$PIPELINE_VERSION\""
    environment = {
      "PIPELINE_VERSION" = "1.8.5"
    }
  }
  depends_on = [null_resource.kubectl_access]
}
