terraform {
  backend "s3" {
    bucket                      = "tfstate"
    key                         = "homelab.tfstate"
    region                      = "garage"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
    endpoints = {
      s3 = "http://garage.antoinejosset.fr:3900"
    }
  }
}
