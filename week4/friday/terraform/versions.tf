terraform {
  required_version = ">= 1.10.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "= 0.9.9"
    }
  }

  backend "s3" {
    bucket = "kijanikiosk-tfstate"
    key    = "week4/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "http://127.0.0.1:9000"
    }

    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}
