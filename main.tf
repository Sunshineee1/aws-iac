# ----------------------------------------------------
# 1.(PROVIDER)
# ----------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Използва AWS ключовете, които конфигурира с 'aws configure'
provider "aws" {
  region = "eu-central-1" 
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ----------------------------------------------------
# 2.(VPC, SUBNETS, INTERNET)
# ----------------------------------------------------

# (VPC)
resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "Failover-Task-VPC"
  }
}

# Public AZ-A (ALB, EC2)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # EC2 инстанциите получават публично IP
  tags = {
    Name = "Public-Subnet-A"
  }
}

# Public AZ-B (ALB, EC2)
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet-B"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "Task-IGW"
  }
}

# (Route Table)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Connect on Route Table with the subnets
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ----------------------------------------------------
# 3.  (SECURITY GROUP)
# ----------------------------------------------------

# Security Group  EC2 
resource "aws_security_group" "web_sg" {
  vpc_id      = aws_vpc.app_vpc.id
  description = "Allow inbound HTTP and SSH traffic"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Всички протоколи
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Web-App-SG"
  }
}

# ----------------------------------------------------
# 4. EC2 instances
# ----------------------------------------------------

# Ubuntu AMI ID за eu-central-1 (Провери за най-новия или го замени)
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

#creatin two EC2 instances 
resource "aws_instance" "web_app" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = count.index == 0 ? aws_subnet.public_a.id : aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # user_data е преместен тук, където 'count.index' е дефиниран!
  user_data = <<-EOT
    #!/bin/bash
    sudo apt update -y
    sudo apt install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "<h1>Hello from EC2 in AZ: ${data.aws_availability_zones.available.names[count.index]}</h1>" | sudo tee /var/www/html/index.html
    EOT
    
  tags = {
    Name = "Web-Instance-${count.index + 1}"
  }
}

# ----------------------------------------------------
# 5. LOAD BALANCER (ALB) and FAIL-OVER
# ----------------------------------------------------

# Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "main-alb-task"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "Task-ALB"
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "main-tg-task"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id
  health_check {
    path                = "/" 
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Reg the two instances in the Target Group
resource "aws_lb_target_group_attachment" "web_attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.web_app[count.index].id
  port             = 80
}

# Listener (listen HTTP traffic on port 80 and send it to Target Group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ----------------------------------------------------
# 6. OUTPUT
# ----------------------------------------------------

# Show the DNS  name on LB
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}



