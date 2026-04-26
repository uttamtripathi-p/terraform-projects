terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = "us-west-2"
}
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "raju-ki-bucket-2"
}
 

resource "aws_instance" "my_instance" {
	ami = "ami-0d76b909de1a0595d"
	instance_type = "t2.micro"
tags = {
    Name = "TerraWeek-Modified"
  }
}
