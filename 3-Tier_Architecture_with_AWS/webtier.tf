# Frontend/Web Tier Configuration

# Internet-facing Load Balancer
resource "aws_lb" "internet_facing_lb" {
  name               = "internet-facing-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_web_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "internet-facing-lb"
  }
}

# Web Tier Target Group
resource "aws_lb_target_group" "internet_facing_tg" {
  name     = "internet-facing-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 3
  }

  tags = {
    Name = "internet-facing-tg"
  }
}

# Web Tier Listener
resource "aws_lb_listener" "internet_facing_listener" {
  load_balancer_arn = aws_lb.internet_facing_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internet_facing_tg.arn
  }
}
