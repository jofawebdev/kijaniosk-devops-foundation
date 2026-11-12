terraform {
  required_version = ">= 1.10.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

resource "kubernetes_namespace_v1" "staging" {
  metadata {
    name = "kijani-staging"

    labels = {
      app         = "kijanikiosk"
      environment = "staging"
      managed-by  = "terraform"
    }
  }
}
