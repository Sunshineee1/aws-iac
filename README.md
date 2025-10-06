# aws-iac

This repository contains the solution for a technical assignment focusing on Infrastructure as Code (Terraform) with fail-over demonstration.

Table of Contents

2. Task 2: Infrastructure as Code (IaC)
The Terraform configuration provisions a resilient, multi-AZ web environment in AWS using the eu-central-1 region.

2.1. Architecture
- VPC: Custom VPC with public subnets spanning two Availability Zones (AZs).
- ALB: An Application Load Balancer distributes traffic across the two zones.
- EC2 Instances: Two t3.micro instances (one in each AZ) running Nginx, configured via user_data script.
- Fail-over: ALB is configured with Health Checks, ensuring traffic is only routed to healthy instances.

2.2. Deployment Steps
- Initialize Terraform:
- terraform init
- Review Plan:terraform plan
- Apply Configuration:terraform apply
- Confirm with yes

2.3. Fail-over Demonstration
The primary goal is to demonstrate automated service fail-over:
Get ALB DNS Name: Use the output from terraform apply: alb_dns_name = "..."

Initial Test: Access the ALB DNS name in a browser. It will show: Hello from EC2 in AZ: eu-central-1a (or -1b).

Simulate Failure: In the AWS Console, manually Stop the EC2 instance corresponding to the active AZ (e.g., stop the instance in eu-central-1a).
Confirm Fail-over: After 30-60 seconds, refresh the browser. The page should automatically switch and display the message from the healthy instance in the other AZ ( Hello from EC2 in AZ: eu-central-1b).

3. Cleanup
To avoid running costs, remember to destroy the provisioned AWS resources after testing:
terraform destroy
- Confirm with yes
