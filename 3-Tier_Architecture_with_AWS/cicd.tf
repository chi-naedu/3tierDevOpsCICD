
resource "aws_codebuild_project" "frontend" {
  name          = "frontend-build"
  service_role  = aws_iam_role.codebuild.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:6.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }
  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
    buildspec       = "3-Tier_Architecture_with_AWS/ci-cd/buildspec-frontend.yml"
    git_clone_depth = 1
  }
}

resource "aws_codebuild_project" "backend" {
  name          = "backend-build"
  service_role  = aws_iam_role.codebuild.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:6.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }
  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
    buildspec       = "3-Tier_Architecture_with_AWS/ci-cd/buildspec-backend.yml"
    git_clone_depth = 1
  }
}

resource "aws_iam_role" "codebuild" {
  name = "codebuild-service-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}
data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "codebuild_ecs" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_developer" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_codepipeline" "main" {
  name     = "three-tier-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.cicd_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn     = var.codestar_connection_arn
        FullRepositoryId  = "${var.github_owner}/${var.github_repo}"
        BranchName        = "main"
        DetectChanges     = "true"
      }
    }
  }

  stage {
    name = "Build-Frontend"
    action {
      name             = "Build-Frontend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["frontend_build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.frontend.name
      }
    }
  }

  stage {
    name = "Build-Backend"
    action {
      name             = "Build-Backend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["backend_build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.backend.name
      }
    }
  }

  stage {
    name = "Deploy-Frontend"
    action {
      name            = "Deploy-Frontend"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["frontend_build_output"]
      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.frontend.name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  stage {
    name = "Deploy-Backend"
    action {
      name            = "Deploy-Backend"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["backend_build_output"]
      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.backend.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name = "codepipeline-service-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline_full" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_s3_bucket" "cicd_artifacts" {
  bucket = "${lower(var.github_repo)}-cicd-artifacts-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}
