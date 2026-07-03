data "aws_iam_policy_document" "alb_controller_assume" {
    statement {
        actions = ["sts:AssumeRoleWithWebIdentity"]
        effect = "Allow"

        principals {
            type = "Federated"
            identifiers = [var.oidc_provider_arn]
        }

        condition {
            test = "StringEquals"
            variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"

            values = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
        }
    }    
}

resource "aws_iam_role" "alb_controller" {
    name = "${var.project_name}-${var.environment}-alb-controller"

    assume_role_policy = data.aws_iam_policy_document.alb_controller_assume.json

    tags = {
        Name = "${var.project_name}-${var.environment}-alb-controller"
    }
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancerControllerPolicy"

    role = aws_iam_role.alb_controller.name
}