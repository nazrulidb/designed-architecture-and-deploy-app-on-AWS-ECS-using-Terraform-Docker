terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==============================================================================
# 1. NETWORKING
# ==============================================================================
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-managed-sg"
  description = "Allow traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 2. IAM ROLES
# ==============================================================================

# --- A. Instance Role ---
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole_New"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInstanceRolePolicyForManagedInstances"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile_New"
  role = aws_iam_role.ecs_instance_role.name
}

# --- B. Infrastructure Role ---
resource "aws_iam_role" "ecs_infra_role" {
  name = "ecsInfrastructureRole_New"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_infra_attach" {
  role       = aws_iam_role.ecs_infra_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForManagedInstances"
}

# ==============================================================================
# 3. CLUSTER (Must be defined BEFORE the Capacity Provider now)
# ==============================================================================
resource "aws_ecs_cluster" "main" {
  name = "my-new-managed-cluster"
}

# ==============================================================================
# 4. CAPACITY PROVIDER
# ==============================================================================

resource "aws_ecs_capacity_provider" "example" {
  name = "example-managed-provider"

    # --- FIX: This argument is required for managed_instances_provider ---
  cluster = aws_ecs_cluster.main.name 

  managed_instances_provider {
    infrastructure_role_arn = aws_iam_role.ecs_infra_role.arn
    propagate_tags          = "CAPACITY_PROVIDER"

    instance_launch_template {
      ec2_instance_profile_arn = aws_iam_instance_profile.ecs_instance_profile.arn
      monitoring               = "BASIC"

      network_configuration {
        subnets         = data.aws_subnets.default.ids
        security_groups = [aws_security_group.ecs_sg.id]
      }

      storage_configuration {
        storage_size_gib = 30
      }

      instance_requirements {
        memory_mib {
          min = 1024
          max = 8192
        }

        vcpu_count {
          min = 1
          max = 4
        }

        instance_generations = ["current"]
        cpu_manufacturers    = ["intel", "amd"]
      }
    }
  }
}

# ==============================================================================
# 5. CLUSTER ASSOCIATION
# ==============================================================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.example.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.example.name
  }
}