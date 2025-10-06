Architecture (Load Balancer -> Web Server -> Database).

Load Balancer (AWS ALB)
Web Server (AWS EC2)
Database (AWS RDS) 

Prerequisites:
	Installed Terraform.
	Installed AWS CLI.

Configured AWS account with the needful access. (~/.aws/credentials).
Setup Instructions:
Clone the repository: git clone git@github.com:Sunshineee1/aws-iac.git
Initialize Terraform: terraform init
Review Plan: terraform plan
Apply Configuration: terraform apply

Infrastructure Management:
Destroying the Infrastructure: terraform destroy

Fail-over: Connection on EC2 with Auto Scaling Group (ASG). If EC2 instance fails , ASG will create new one (Fail-over).
