# Optional Bastion Host Configuration
# ONLY enable this if you need SSH access to worker nodes
# Most users don't need this - kubectl provides everything

# Uncomment this entire file to create a bastion host

/*

# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  # Allow SSH from your IP only
  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP_ADDRESS/32"]  # Replace with your IP
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-bastion-sg"
    }
  )
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
  
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name              = var.bastion_key_name  # You need to create this key pair
  
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y curl wget
              
              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              
              # Install AWS CLI
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install
              EOF

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-bastion"
    }
  )
}

# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Output bastion public IP
output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

# Variable for SSH key
variable "bastion_key_name" {
  description = "SSH key pair name for bastion host"
  type        = string
  default     = "my-key-pair"  # Replace with your key pair name
}

*/

# Instructions to enable:
# 1. Uncomment all code above
# 2. Replace YOUR_IP_ADDRESS with your actual IP (curl ifconfig.me)
# 3. Create an AWS key pair in us-west-1
# 4. Update bastion_key_name variable
# 5. Run: terraform apply

# To use bastion:
# ssh -i your-key.pem ec2-user@<bastion-public-ip>
# aws eks update-kubeconfig --name test-cluster-cluster --region us-west-1
# kubectl get nodes

