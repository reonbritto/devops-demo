provider "aws" {
  region = "eu-north-1"
}


resource "aws_s3_bucket" "example" {
  bucket = "reon-tf-eks-state-bucket"

lifecycle{
    prevent_destroy = false
 }
}


resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "reon-tf-eks-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}