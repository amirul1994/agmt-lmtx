resource "aws_iam_role" "bastion" {
    name = "${var.project_name}-${var.environment}-bastion-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"

        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })

    tags = {
        Name = "${var.project_name}-${var.environment}-bastion-role"
    }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role = aws_iam_role.bastion.name
}

resource "aws_iam_instance_profile" "bastion" {
    name = "${var.project_name}-${var.environment}-bastion-profile"

    role = aws_iam_role.bastion.name
} 

resource "aws_instance" "bastion" {
    ami = var.ami_id

    instance_type = var.instance_type 

    subnet_id = var.public_subnet_id 

    vpc_security_group_ids = [var.bastion_security_group_id]

    iam_instance_profile = aws_iam_instance_profile.bastion.name

    key_name = var.key_name

    user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y postgresql-client telnet
              curl -fsSL https://aws-ssm-agent.s3.amazonaws.com/debian/aws-ssm-agent.gpg | apt-key add -
              echo "deb [arch=amd64] https://aws-ssm-agent.s3.amazonaws.com/debian stable main" | tee /etc/apt/sources.list.d/aws-ssm-agent.list
              apt-get update -y
              apt-get install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOF 
    
    tags = {
        Name = "${var.project_name}-${var.environment}-bastion"
    }
}