resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.project_name}/rds/credentials1"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db.result
  })
}

resource "random_password" "db" {
  length  = 16
  special = true
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnets

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-db"

  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = jsondecode(aws_secretsmanager_secret_version.db.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.db.secret_string)["password"]

  multi_az               = true
  publicly_accessible    = false
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds.arn
  deletion_protection    = false # set to true in production
  backup_retention_period = 7
  skip_final_snapshot    = true # set to false in production

  vpc_security_group_ids = [var.db_sg_id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  tags = {
    Name = "${var.project_name}-rds"
  }
}

