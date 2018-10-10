module "vpc" {
  providers = {
    "aws" = "aws.us-west"
  }

  source = "terraform-aws-modules/vpc/aws"

  name = "vpc-vault"
  cidr = "10.10.0.0/16"

  azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnets      = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  database_subnets    = ["10.10.21.0/24", "10.10.22.0/24", "10.10.23.0/24"]
  elasticache_subnets = ["10.10.31.0/24", "10.10.32.0/24", "10.10.33.0/24"]
  redshift_subnets    = ["10.10.41.0/24", "10.10.42.0/24", "10.10.43.0/24"]
  intra_subnets       = ["10.10.51.0/24", "10.10.52.0/24", "10.10.53.0/24"]

  create_database_subnet_group = false

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_vpn_gateway = true

  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  enable_dhcp_options              = true
  dhcp_options_domain_name         = "dhcp.acute.care"
  dhcp_options_domain_name_servers = ["127.0.0.1", "10.10.0.2"]

  tags = {
    Owner       = "jon.daniel@ge.com"
    Environment = "engineering"
    Name        = "vpc-complete"
    Product     = "Acute Care"
  }
}

module "us-west" {
  providers = {
    "aws" = "aws.us-west"
  }

  source = "modules/vault"

  # Environment
  env       = "${ var.env }"
  region    = "${ var.region }"
  dr_region = "${ var.dr_region }"
  tags      = "${ var.tags }"
  tags_asg  = "${ var.tags_asg }"

  # Networking
  vault_dns_address         = "${ var.vault_dns_address }"
  vpc_id                    = "${ var.vpc_id }"
  alb_subnets               = "${ var.alb_subnets }"
  ec2_subnets               = "${ var.ec2_subnets }"
  alb_allowed_ingress_cidrs = "${ var.alb_allowed_ingress_cidrs }"
  alb_allowed_egress_cidrs  = "${ var.alb_allowed_egress_cidrs }"

  # ALB
  alb_certificate_arn = "${ var.alb_certificate_arn }"

  # EC2
  ami_id               = "${ var.ami_id }"
  instance_type        = "${ var.instance_type }"
  ssh_key_name         = "${ var.ssh_key_name }"
  asg_min_size         = "${ var.asg_min_size }"
  asg_max_size         = "${ var.asg_max_size }"
  asg_desired_capacity = "${ var.asg_desired_capacity }"

  # S3
  vault_resources_bucket_name = "${ var.vault_resources_bucket_name }"
  vault_data_bucket_name      = "${ var.vault_data_bucket_name }"

  # DynamoDB
  dynamodb_table_name = "${ var.dynamodb_table_name }"
}
