resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "public-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-1"
  }
}

resource "aws_subnet" "public-2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-2"
  }
}

resource "aws_subnet" "web-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.environment}-web-1"
  }
}

resource "aws_subnet" "web-2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.environment}-web-2"
  }
}

resource "aws_subnet" "database-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.environment}-database-1"
  }
}

resource "aws_subnet" "database-2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.environment}-database-2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_eip" "nat-a" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-eip-nat-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat-b" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-eip-nat-b"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateways - one per AZ
resource "aws_nat_gateway" "nat-az-a" {
  subnet_id     = aws_subnet.public-1.id
  allocation_id = aws_eip.nat-a.id

  tags = {
    Name = "${var.environment}-nat-az-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat-az-b" {
  subnet_id     = aws_subnet.public-2.id
  allocation_id = aws_eip.nat-b.id

  tags = {
    Name = "${var.environment}-nat-az-b"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment}-rt-public"
  }
}

resource "aws_route_table" "private_az_a" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-az-a.id
  }

  tags = {
    Name = "${var.environment}-rt-private-az-a"
  }
}

resource "aws_route_table" "private_az_b" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-az-b.id
  }

  tags = {
    Name = "${var.environment}-rt-private-az-b"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "web_az_a" {
  subnet_id      = aws_subnet.web-1.id
  route_table_id = aws_route_table.private_az_a.id
}

resource "aws_route_table_association" "web_az_b" {
  subnet_id      = aws_subnet.web-2.id
  route_table_id = aws_route_table.private_az_b.id
}

resource "aws_route_table_association" "database_az_a" {
  subnet_id      = aws_subnet.database-1.id
  route_table_id = aws_route_table.private_az_a.id
}

resource "aws_route_table_association" "database_az_b" {
  subnet_id      = aws_subnet.database-2.id
  route_table_id = aws_route_table.private_az_b.id
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-alb-sg"
  description = "Allow HTTP and HTTPS inbound traffic to ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.environment}-ecs-sg"
  description = "Allow inbound traffic from ALB only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-ecs-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-sg"
  description = "Allow inbound traffic from ECS tasks only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow Postgres from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-rds-sg"
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.environment}-ecs-task-role"
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.environment}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.environment}-ecs-secrets-policy"
  description = "Allow ECS tasks to read RDS credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_db_instance.rds.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}

resource "aws_ecs_cluster" "nginx_cluster" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.environment}-${var.service}"
  retention_in_days = 30

  tags = {
    Name = "${var.environment}-${var.service}-logs"
  }
}

resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "${var.environment}-${var.service}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "nginx-container"
    image = "nginx:latest"

    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}-${var.service}"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name = "${var.environment}-${var.service}-task"
  }
}

resource "aws_ecs_service" "nginx_service" {
  name                              = "${var.environment}-${var.service}"
  cluster                           = aws_ecs_cluster.nginx_cluster.id
  task_definition                   = aws_ecs_task_definition.nginx_task.arn
  launch_type                       = "FARGATE"
  desired_count                     = 2
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [aws_subnet.web-1.id, aws_subnet.web-2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
    container_name   = "nginx-container"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.nginx_listener,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = {
    Name = "${var.environment}-${var.service}"
  }
}

resource "aws_db_subnet_group" "subnet_group" {
  name        = "${var.environment}-db-subnet-group"
  description = "Database subnet group for ${var.environment}"
  subnet_ids  = [aws_subnet.database-1.id, aws_subnet.database-2.id]

  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "rds" {
  identifier        = "${var.environment}-postgres"
  allocated_storage = 10
  storage_type      = "gp3"
  storage_encrypted = true

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-postgres-final-snapshot"
  deletion_protection       = true

  tags = {
    Name = "${var.environment}-postgres"
  }
}