terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

locals {
  repo = "github-terraform-task-yoorita"
  username = "softservedata"
  dev_branch = "develop"
  pr_template_content = <<EOT
    ## Describe your changes

    ## Issue ticket number and link

    ## Checklist before requesting a review
    - [ ] I have performed a self-review of my code
    - [ ] If it is a core feature, I have added thorough tests
    - [ ] Do we need to implement analytics?
    - [ ] Will this be part of a product update? If yes, please write one phrase about this update
  EOT
}

provider "github" {
  owner = "Practical-DevOps-GitHub"
  token = var.pat_token
}

resource "github_repository_collaborator" "collaborator" {
  repository = local.repo
  username   = local.username
  permission = "push"
}

resource "github_branch" "develop_branch" {
  repository = local.repo
  branch     = local.dev_branch
}

resource "github_branch_default" "default"{
  repository = local.repo
  branch     = github_branch.develop_branch.branch
}

resource "github_branch_protection" "main_branch_protection" {
  repository_id = local.repo
  pattern = "main"

  required_pull_request_reviews {
    require_code_owner_reviews = true
    required_approving_review_count = 0
  }
}

resource "github_branch_protection" "develop_branch_protection" {
  repository_id = local.repo
  pattern = local.dev_branch

  required_pull_request_reviews {
    required_approving_review_count = 2
  }
}

resource "github_repository_file" "codeowners" {
  repository          = local.repo
  branch              = "main"
  file                = ".github/CODEOWNERS"
  content             = format("* @%s", local.username)
  overwrite_on_create = true
}

resource "github_repository_file" "main_pull_request_template" {
  repository          = local.repo
  branch              = "main"
  file                = ".github/pull_request_template.md"
  content             = local.pr_template_content
  overwrite_on_create = true
}

resource "github_repository_file" "develop_pull_request_template" {
  repository          = local.repo
  branch              = local.dev_branch
  file                = ".github/pull_request_template.md"
  content             = local.pr_template_content
  overwrite_on_create = true
  depends_on = [ github_branch.develop_branch ]
}

resource "github_repository_deploy_key" "repository_deploy_key" {
  title      = "DEPLOY_KEY"
  repository = local.repo
  key        = var.deploy_key
  read_only  = true
}

resource "github_repository_webhook" "discord_server_message" {
  repository = local.repo

  configuration {
    url          = var.discord_webhook
    content_type = "application/json"
  }

  active = false

  events = ["pull_request"]
}

resource "github_actions_secret" "pat_secret" {
  repository       = local.repo
  secret_name      = "PAT"
  plaintext_value  = var.pat_token
}