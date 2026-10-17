# ---------- Account B (111111111111) ----------

resource "aws_s3_bucket" "shared" {
  provider = aws.account_b
  bucket   = var.shared_bucket_name
}

# roleC: full access to exactly one bucket, assumable ONLY by roleB's ARN.
resource "aws_iam_role" "roleC" {
  provider = aws.account_b
  name     = "roleC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_a_id}:role/roleB" }
    }]
  })
}

resource "aws_iam_role_policy" "roleC_bucket_full_access" {
  provider = aws.account_b
  name     = "single-bucket-full-access"
  role     = aws_iam_role.roleC.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BucketLevel"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.shared_bucket_name}"
      },
      {
        Sid      = "ObjectLevel"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.shared_bucket_name}/*"
      }
    ]
  })
}
