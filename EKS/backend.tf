terraform {
  backend "s3" {
    bucket = "devops-terraform-backend-ap-south-2"
    key    = "eks/terraform.tfstate"
    region = "ap-south-2"
  }
}