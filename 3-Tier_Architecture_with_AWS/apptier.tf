# Backend/Application Tier Configuration

# Internal Load Balancer
# resource "aws_lb" "internal_lb" {
#   name               = "app-internal-lb"
#   internal           = true
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb_app_sg.id]
#   subnets            = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

#   tags = {
#     Name = "app-internal-lb"
#   }
# }

# App Tier Target Group
resource "aws_lb_target_group" "internal_tg" {
  name     = "app-internal-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "app-internal-tg"
  }
}

# App Tier Listener
# resource "aws_lb_listener" "internal_listener" {
#   load_balancer_arn = aws_lb.internal_lb.arn
#   port              = "5000"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.internal_tg.arn
#   }
# }
