#Create Application Load Balancer
resource "aws_alb" "app_alb" {
  name               = "app-alb"
  subnets            = [aws_subnet.main_a.id, aws_subnet.main_b.id]
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name = "app-alb"
  }
}


#Create Target Groups for Application Load Balancer
resource "aws_alb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"  # Correct attribute value for awsvpc network mode

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

#Create Listners for Target Group
resource "aws_alb_listener" "app_listener" {
  load_balancer_arn = aws_alb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.app_tg.arn
  }
}
