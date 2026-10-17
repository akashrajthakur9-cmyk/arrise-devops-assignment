terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "account_a_id" {
  type    = string
  default = "000000000000"
}

variable "shared_bucket_name" {
  type    = string
  default = "account-b-shared-bucket"
}

# FIX 1: roleB is an IAM role, so its ARN uses the role/ path, not user/.
data "aws_iam_policy_document" "roleC_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:role/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
}

# FIX 2: scope the permissions to the one intended bucket (bucket-level ARN
# for bucket actions, bucket/* for object actions) instead of Resource "*".
resource "aws_iam_role_policy" "roleC_s3" {
  name = "roleC-s3-access"
  role = aws_iam_role.roleC.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.shared_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.shared_bucket_name}/*"
      }
    ]
  })
}
