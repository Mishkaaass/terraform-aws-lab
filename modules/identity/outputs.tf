output "instance_profile_name" { value = aws_iam_instance_profile.instance.name }
output "role_name" { value = aws_iam_role.instance.name }
output "managed_policy_arn" { value = aws_iam_role_policy_attachment.ssm.policy_arn }
output "assume_role_policy" { value = aws_iam_role.instance.assume_role_policy }
