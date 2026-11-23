locals {
  ec2_trust = {
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  }
}
resource "aws_iam_role" "instance" {
  name_prefix        = "${var.name}-ec2-"
  assume_role_policy = jsonencode(local.ec2_trust)
  tags               = var.tags
}

# AWS-managed narrowly-scoped SSM agent permissions, NOT AdministratorAccess.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.name}-ec2-"
  role        = aws_iam_role.instance.name
  tags        = var.tags
}
