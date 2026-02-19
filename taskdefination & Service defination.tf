# ==============================================================================
# IAM ROLE FOR TASK EXECUTION
# (Required so ECS can pull Docker images from DockerHub/ECR)
# ==============================================================================
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole_App"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==============================================================================
# TASK DEFINITION
# ==============================================================================
resource "aws_ecs_task_definition" "app" {
  family             = "my-managed-app"
  network_mode       = "awsvpc" # Best practice, even for EC2
  cpu                = 256
  memory             = 512
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  
  # We only specify EC2 because we are not using Fargate
  requires_compatibilities = ["EC2"] 

  container_definitions = jsonencode([
    {
      name      = "nginx-app"
      image     = "wordpress:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ==============================================================================
# ECS SERVICE
# ==============================================================================
resource "aws_ecs_service" "main" {
  name            = "my-nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  # --- CAPACITY PROVIDER STRATEGY ---
  # This tells the service to use your Managed Instances (EC2)
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.example.name
    weight            = 100
  }

  # --- NETWORK CONFIGURATION ---
  # Required because we used network_mode = "awsvpc"
  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_sg.id] # Re-using the SG from managed.tf
  }

  # --- LOAD BALANCER ---
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "nginx-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.front_end]
}