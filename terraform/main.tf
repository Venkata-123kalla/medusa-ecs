provider "aws" {
  region = "us-east-1"
}

# Data block to fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Data block to fetch default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs" {
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "medusa-security-group"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "medusa-cluster"
}

# ECS Service with Fargate Spot
resource "aws_ecs_service" "medusa" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = "arn:aws:ecs:us-east-1:396913738987:task-definition/medusa-task"
  desired_count   = 1

  # Define capacity provider strategy for Fargate Spot
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role_new" {
  name = "ecs_execution_role_new"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_execution_policy_new" {
  role       = aws_iam_role.ecs_execution_role_new.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
