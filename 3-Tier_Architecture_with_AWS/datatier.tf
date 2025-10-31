# Database Tier: RDS MySQL with master-slave replication

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags = { Name = "main-db-subnet-group" }
}

resource "aws_db_instance" "database_master" {
  identifier              = "db-master"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_encrypted       = true
  username                = "admin"
  password                = "appdbpassword123$"
  db_name                 = "app-db"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  multi_az                = false
  backup_retention_period = 7
  publicly_accessible     = false
  skip_final_snapshot     = true
  tags = { Name = "db-master" }
}

resource "aws_db_instance" "database_slave" {
  identifier               = "db-slave"
  engine                   = "mysql"
  engine_version           = "8.0"
  instance_class           = "db.t3.micro"
  allocated_storage        = 20
  storage_encrypted        = true
  password                 = "appdbpassword123$"
  db_subnet_group_name     = aws_db_subnet_group.main.name
  vpc_security_group_ids   = [aws_security_group.db_sg.id]
  multi_az                 = false
  publicly_accessible      = false
  skip_final_snapshot      = true
  replicate_source_db      = aws_db_instance.database_master.arn
  tags = { Name = "db-slave" }
}
