# ==============================================================================
# IAM ROLE FOR AUTO SCALING

resource "aws_iam_role" "ecs_auto_scale_role" {
  name = "ecsAutoScaleRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "application-autoscaling.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_auto_scale_role_policy" {
  role       = aws_iam_role.ecs_auto_scale_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

# 1. AUTO SCALING TARGET
# (This registers the ECS Service as something that can be scaled)
# ==============================================================================
resource "aws_appautoscaling_target" "ecs_target" {
  # The range of TASKS you want to run
  min_capacity       = 2
  max_capacity       = 10
  
  # Reference to your specific service
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  
  # What are we scaling? The Desired Count of tasks.
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# ==============================================================================
# 2. SCALING POLICY (CPU BASED)
# (Target Tracking is the modern, easiest way to scale)
# ==============================================================================
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    # "Keep the Average CPU of my Service at 70%"
    target_value = 70.0
    
    # How long to wait before scaling again (to prevent flapping)
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ==============================================================================
# 3. SCALING POLICY (MEMORY BASED - OPTIONAL)
# (Uncomment if your app is memory heavy instead of CPU heavy)
# ==============================================================================
/*
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
*/