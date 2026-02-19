# ==============================================================================
# ALB SECURITY GROUP
# ==============================================================================
resource "aws_security_group" "alb_sg" {
  name        = "ecs-alb-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# ==============================================================================
# LOAD BALANCER
# ==============================================================================
resource "aws_lb" "main" {
  name               = "ecs-managed-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "app" {
  name        = "ecs-managed-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  
  # IMPORTANT: We use "ip" because we will use 'awsvpc' network mode in the Task Definition.
  # This allows the ALB to talk directly to the Pod/Task IP, even on EC2.
  target_type = "ip" 

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}