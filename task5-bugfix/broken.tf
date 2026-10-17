# Original snippet from the assignment, kept for reference. DO NOT USE.
# Bug 1: trust policy references arn:aws:iam::000000000000:user/roleB,
#        but roleB is a ROLE, not a user - the ARN path is wrong, so the
#        principal never matches and the assume call is denied.
# Bug 2: the permissions policy grants s3:* on Resource "*", i.e. every
#        bucket in the account, instead of the one intended bucket.

data "aws_iam_policy_document" "roleC_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::000000000000:user/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
}

resource "aws_iam_role_policy" "roleC_s3" {
  name = "roleC-s3-access"
  role = aws_iam_role.roleC.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = "*"
    }]
  })
}
