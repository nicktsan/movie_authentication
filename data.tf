data "template_file" "lambda_assume_role_policy" {
  template = file("./template/lambda_assume_role_policy.tpl")
}

data "template_file" "lambda_iam_policy" {
  template = file("./template/lambda_iam_policy.tpl")
}

data "archive_file" "deps_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/deps-layer/"
  output_path = "${path.module}/lambda/dist/deps.zip"
}

data "archive_file" "utils_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/util-layer/"
  output_path = "${path.module}/lambda/dist/utils.zip"
}

data "archive_file" "post_confirmation_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/handlers/post_confirmation_lambda/"
  output_path = "${path.module}/lambda/dist/post_confirmation_lambda.zip"
}

data "hcp_vault_secrets_secret" "stripeSecret" {
  app_name    = "movie-app"
  secret_name = var.stripe_secret_key
}

data "aws_iam_policy_document" "admin_group_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = ["us-east-1:12345678-dead-beef-cafe-123456790ab"]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["authenticated"]
    }
  }
}
