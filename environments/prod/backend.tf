terraform {
  backend "s3" {
    bucket         = "three-tier-practice"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
  }
}
