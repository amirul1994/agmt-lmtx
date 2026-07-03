output "bastion_ssm_command" {
    value = "aws ssm start-session --target ${module.bastion.instance_id}"
}

output "alb_controller_irsa_role_arn" {
    value = module.iam.alb_controller_role_arn
}