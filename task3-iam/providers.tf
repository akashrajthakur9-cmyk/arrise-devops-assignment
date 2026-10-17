terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Two aliased providers, one per account. Point each at credentials for that
# account (profiles here; in CI you would use assume_role instead).
provider "aws" {
  alias   = "account_a"
  region  = "ap-south-1"
  profile = var.account_a_profile
}

provider "aws" {
  alias   = "account_b"
  region  = "ap-south-1"
  profile = var.account_b_profile
}

variable "account_a_profile" {
  description = "AWS CLI profile for Account A (000000000000)"
  type        = string
  default     = "account-a"
}

variable "account_b_profile" {
  description = "AWS CLI profile for Account B (111111111111)"
  type        = string
  default     = "account-b"
}

variable "account_a_id" {
  type    = string
  default = "000000000000"
}

variable "account_b_id" {
  type    = string
  default = "111111111111"
}

variable "shared_bucket_name" {
  description = "The single S3 bucket in Account B that roleC gets full access to"
  type        = string
  default     = "account-b-shared-bucket"
}
