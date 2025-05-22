data "aws_iam_policy" "s3_access" {
  name = "AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role" "s3_access" {
  name = "ar-${var.general.key_name}-${var.general.attack_range_name}-s3-access"
  tags = {
    Name = "ar-${var.general.key_name}-${var.general.attack_range_name}-s3-access"
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

# Attach the S3 read-only policy to the role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.s3_access.name
  policy_arn = data.aws_iam_policy.s3_access.arn
}

# Create an inline policy for KMS decrypt
resource "aws_iam_role_policy" "kms_decrypt_policy" {
  name = "kms-decrypt-policy"
  role = aws_iam_role.s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create an inline policy for SSM and EC2 messages
resource "aws_iam_role_policy" "ssm_policy" {
  name = "ssm-policy"
  role = aws_iam_role.s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:ListInstanceAssociations",
          "ssm:PutComplianceItems",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "s3:Get*",
          "s3:List*",
          "s3:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "s3_access" {
  name = "ar-${var.general.key_name}-${var.general.attack_range_name}-instance-profile"
  path = "/"
  role = aws_iam_role.s3_access.name
}
