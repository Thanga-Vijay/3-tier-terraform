module "vpc" {
  source = "../../modules/vpc"

  project_name    = var.project_name
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  db_subnets      = var.db_subnets
}

module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  app_port     = var.app_port
  db_port      = var.db_port
}

module "alb" {
  source = "../../modules/alb"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  public_subnets   = module.vpc.public_subnets
  alb_sg_id        = module.security_groups.alb_sg_id
  enable_https = false # true if production environment
  # certificate_arn = var.certificate_arn # uncomment if production environment
  app_port         = var.app_port
}

module "asg" {
  source = "../../modules/asg"

  project_name      = var.project_name
  vpc_id           = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  app_sg_id         = module.security_groups.app_sg_id
  target_group_arn = module.alb.target_group_arn

  instance_type    = var.instance_type
  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size
  app_port         = var.app_port
}

module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  db_name      = var.db_name

  engine            = var.db_engine
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  vpc_id     = module.vpc.vpc_id
  db_subnets = module.vpc.db_subnets
  db_sg_id   = module.security_groups.db_sg_id
}

module "s3_app" {
  source = "../../modules/s3"

  bucket_name = "${var.project_name}-${var.environment}-assets"
  environment = var.environment
}
