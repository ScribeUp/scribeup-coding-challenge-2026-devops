# Production Postgres. Separate state from ../core so a mistake there can't touch
# the database. LocalStack doesn't run RDS, so locally this directory is only
# validated, never planned or applied.

resource "aws_db_subnet_group" "main" {
  name       = "scan-${var.environment}"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name   = "scan-db-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    description = "Postgres (the data team connects from their laptops for reporting)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier              = "scan-${var.environment}"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = "db.m6g.large"
  allocated_storage       = 300
  db_name                 = "scan"
  username                = "scan_admin"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = true
  storage_encrypted       = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  apply_immediately       = true
}
