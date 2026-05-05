provider "aws" {
  region = "us-east-1"
}

# -------------------------
# S3 Bucket for pipeline artifacts
# -------------------------
resource "aws_s3_bucket" "pipeline_bucket" {
  bucket = "zahedur-pipeline-bucket-1217"
}

# -------------------------
# GET DEFAULT SECURITY GROUP
# -------------------------
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = "vpc-0388858cd9966a2da"
}

# -------------------------
# APPLICATION LOAD BALANCER
# -------------------------
resource "aws_lb" "app_lb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [data.aws_security_group.default.id]

  subnets = [
    "subnet-09a8b76c9134c6899",
    "subnet-093d2031c8979d00f"
  ]
}

# -------------------------
# TARGET GROUP
# -------------------------
resource "aws_lb_target_group" "tg" {
  name        = "ecs-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-0388858cd9966a2da"
  target_type = "ip"
}

# -------------------------
# LISTENER
# -------------------------
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# -------------------------
# CODEDEPLOY APPLICATION
# -------------------------
resource "aws_codedeploy_app" "ecs_app" {
  name             = "ecs-app"
  compute_platform = "ECS"
}

# -------------------------
# CODEDEPLOY DEPLOYMENT GROUP
# -------------------------
resource "aws_codedeploy_deployment_group" "ecs_group" {
  app_name              = aws_codedeploy_app.ecs_app.name
  deployment_group_name = "ecs-deploy-group"

  service_role_arn = "arn:aws:iam::067856596210:role/codedeployRole"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = "zahedurcluster"
    service_name = "zahedur-service"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.front_end.arn]
      }

      target_group {
        name = aws_lb_target_group.tg.name
      }
    }
  }
}

# -------------------------
# CODEPIPELINE
# -------------------------
resource "aws_codepipeline" "pipeline" {
  name     = "ecs-pipeline"
  role_arn = "arn:aws:iam::067856596210:role/codepipelineRole"

  artifact_store {
    location = aws_s3_bucket.pipeline_bucket.bucket
    type     = "S3"
  }

  # ---------------- SOURCE (ECR) ----------------
  stage {
    name = "Source"

    action {
      name             = "ECR-Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = "nginx"
        ImageTag       = "latest"
      }
    }
  }

  # ---------------- DEPLOY ----------------
  stage {
    name = "Deploy"

    action {
      name            = "Deploy-to-ECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.ecs_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.ecs_group.deployment_group_name
      }
    }
  }
}