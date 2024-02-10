#Create ECR Private Repo

resource "aws_ecr_repository" "app_repo" {
  name = "app-repo" # Change this to your repo name
}

#Create ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "app-cluster"
}

#Iam Role for ECS
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


#Iam Role For EC2 Instance which runs for ECS
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


# Role For LC
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}


#Task Definition for ECS
resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "app",
      image     = aws_ecr_repository.app_repo.repository_url # Replace with your ECR image URL
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = 5000,
          hostPort      = 5000
        }
      ]
    }
  ])
}

#Create ECS Service

resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets          = [aws_subnet.main_a.id, aws_subnet.main_b.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app_tg.arn
    container_name   = "app"
    container_port   = 5000
  }
}


#Fetch Latest AMI 

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"] # Amazon's owner ID

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# Define LC for Autoscaling

resource "aws_launch_configuration" "ecs_launch_config" {
  name_prefix          = "ecs-"
  image_id             = data.aws_ami.ecs_ami.id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  # Ensuring the ECS agent registers with the correct cluster
  user_data = <<-EOF
                #!/bin/bash
                echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

#Autoscaling Group for our application which runs on ECS based on EC2 Instances

resource "aws_autoscaling_group" "ecs_asg" {
  launch_configuration = aws_launch_configuration.ecs_launch_config.id
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.main_a.id, aws_subnet.main_b.id]

  tag {
    key                 = "Name"
    value               = "ECS Instance"
    propagate_at_launch = true
  }
}

#Target Tracking policy 75%
resource "aws_autoscaling_policy" "ecs_asg_target_tracking" {
  name                   = "ecs-asg-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
  }
}
