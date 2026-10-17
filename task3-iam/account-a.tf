# ---------- Account A (000000000000) ----------

# group1: CLI / programmatic access only (access keys, no console password)
resource "aws_iam_group" "group1" {
  provider = aws.account_a
  name     = "group1"
}

resource "aws_iam_user" "engine" {
  provider = aws.account_a
  name     = "engine"
}

resource "aws_iam_user" "ci" {
  provider = aws.account_a
  name     = "ci"
}

resource "aws_iam_user_group_membership" "engine" {
  provider = aws.account_a
  user     = aws_iam_user.engine.name
  groups   = [aws_iam_group.group1.name]
}

resource "aws_iam_user_group_membership" "ci" {
  provider = aws.account_a
  user     = aws_iam_user.ci.name
  groups   = [aws_iam_group.group1.name]
}

# group2: full console + CLI access (console passwords + access keys)
resource "aws_iam_group" "group2" {
  provider = aws.account_a
  name     = "group2"
}

resource "aws_iam_user" "alice" {
  provider = aws.account_a
  name     = "alice"
}

resource "aws_iam_user" "bob" {
  provider = aws.account_a
  name     = "bob"
}

resource "aws_iam_user_group_membership" "alice" {
  provider = aws.account_a
  user     = aws_iam_user.alice.name
  groups   = [aws_iam_group.group2.name]
}

resource "aws_iam_user_group_membership" "bob" {
  provider = aws.account_a
  user     = aws_iam_user.bob.name
  groups   = [aws_iam_group.group2.name]
}

# Console passwords for group2 users (group1 gets none - CLI only).
resource "aws_iam_user_login_profile" "alice" {
  provider                = aws.account_a
  user                    = aws_iam_user.alice.name
  password_reset_required = true
}

resource "aws_iam_user_login_profile" "bob" {
  provider                = aws.account_a
  user                    = aws_iam_user.bob.name
  password_reset_required = true
}

# roleA: administrative access to every AWS service except IAM.
resource "aws_iam_role" "roleA" {
  provider = aws.account_a
  name     = "roleA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" }
    }]
  })
}

resource "aws_iam_role_policy" "roleA_admin_except_iam" {
  provider = aws.account_a
  name     = "admin-except-iam"
  role     = aws_iam_role.roleA.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAllServices"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        Sid      = "DenyIAM"
        Effect   = "Deny"
        Action   = "iam:*"
        Resource = "*"
      }
    ]
  })
}

# roleB: its ONLY permission is assuming roleC in Account B.
resource "aws_iam_role" "roleB" {
  provider = aws.account_a
  name     = "roleB"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" }
    }]
  })
}

resource "aws_iam_role_policy" "roleB_assume_roleC" {
  provider = aws.account_a
  name     = "assume-roleC"
  role     = aws_iam_role.roleB.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeRoleCOnly"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${var.account_b_id}:role/roleC"
    }]
  })
}
