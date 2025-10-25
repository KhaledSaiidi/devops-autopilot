terraform {
  backend "s3" {
    bucket         = "devops-autopilot-bucket"
    key            = "devops-autopilot.tfstate"
    region         = "us-east-1"
    dynamodb_table = "devops-autopilot-dynamo-table"
  }
}