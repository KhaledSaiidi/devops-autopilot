terraform {
  backend "s3" {
    bucket         = var.bucket
    key            = var.state_key
    region         = var.aws_region
    dynamodb_table = var.dynamodb_table
    encrypt        = true
  }
}