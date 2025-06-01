# Terraform Docker API with Auto Scaling and Load Balancer

This project deploys a Dockerized app (like Nginx) to AWS using:

- EC2 with Docker
- Auto Scaling Group (ASG)
- Application Load Balancer (ALB)
- CloudWatch-based scaling

To use:
1. Copy `terraform.tfvars.example` → `terraform.tfvars`
2. Fill in your values (VPC ID, subnets, key name)
3. Run:
```bash
terraform init
terraform apply
