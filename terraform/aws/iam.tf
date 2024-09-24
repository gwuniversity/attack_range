data "aws_iam_policy" "this" {
  name = "AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role" "this" {
  name = "ar-${var.general.key_name}-${var.general.attack_range_name}-role"
  tags = {
    Name = "ar-${var.general.key_name}-${var.general.attack_range_name}-role"
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = data.aws_iam_policy.this.arn
}

resource "aws_iam_instance_profile" "this" {
  name = "ar-${var.general.key_name}-${var.general.attack_range_name}-instance-profile"
  path = "/"
  role = aws_iam_role.this.name
}
