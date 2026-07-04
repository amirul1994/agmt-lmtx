output "bastion_ssm_command" {
    value = "aws ssm start-session --target ${module.bastion.instance_id}"
}

output "alb_controller_irsa_role_arn" {
    value = module.iam.iam_role_arn
}

output "backend_irsa_role_arn" {
    value = module.backend_irsa.iam_role_arn
}