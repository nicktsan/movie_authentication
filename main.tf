resource "aws_cognito_user_pool" "userpool" {
  name = var.userpool_name

  schema {
    name                     = "Email"
    attribute_data_type      = "String"
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  //cognito auto sends the confirmation code or link to auto_verified_attributes, so when a new user is 
  //created an email and(or) sms will be sent with the confirmation code or link, with link being only to email.
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  //The default_email_option if set to CONFIRM_WITH_CODE cognito will send a code that you will have to provide a 
  //way to the user input the received code and you confirm it with cognito in order to the account be confirmed
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Account Confirmation"
    email_message        = "Your confirmation code is {####}"
  }

  username_attributes = ["email"]
  username_configuration {
    case_sensitive = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  lambda_config {
    post_confirmation = aws_lambda_function.post_confirmation_lambda.arn
  }
}

resource "aws_cognito_user_pool_domain" "moviedomain" {
  domain       = var.userpool_domain
  user_pool_id = aws_cognito_user_pool.userpool.id
}

resource "aws_cognito_user_pool_client" "userpool_client" {
  name         = var.userpool_client_name
  user_pool_id = aws_cognito_user_pool.userpool.id
  //set allowed_oauth_flows_user_pool_client to true to avoid the following error: Client is not enabled for OAuth2.0 flows
  allowed_oauth_flows_user_pool_client = true
  //The following four arguments (supported_identity_providers, callback_urls, allowed_oauth_flows, allowed_oauth_scopes) 
  //are required for next auth to work with aws cognito
  supported_identity_providers = ["COGNITO"]
  callback_urls                = [var.userpool_client_callback_url]
  allowed_oauth_flows          = ["code"]
  allowed_oauth_scopes         = ["email", "openid", "profile"]
  //The explicity_auth_flows represents the actions the client can handle in matters of authentication.
  //EALLOW_USER_SRP_AUTH to enable SRP (secure remote password) protocol based authentication 
  //ALLOW_REFRESH_TOKEN_AUTH to enable the authentication tokens to be refreshed.
  //ALLOW_USER_PASSWORD_AUTH to enable user authentication by username(in our case email) and password .
  //ALLOW_ADMIN_USER_PASSWORD_AUTH to enable user authentication with credentials created by the admin.
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH",
  "ALLOW_USER_PASSWORD_AUTH", "ALLOW_ADMIN_USER_PASSWORD_AUTH"]
  generate_secret = true
  //The prevent_user_existence_errors should always be set to ENABLED in order to the error message to not 
  //point out if the username or the password is wrong as it uses a generic user not found message
  prevent_user_existence_errors = "ENABLED"
  refresh_token_validity        = 1
  access_token_validity         = 1
  id_token_validity             = 1
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "hours"
  }
}

#IAM role for the lambda function
resource "aws_iam_role" "iam_for_lambda" {
  name = var.tf_lambda_iam_role

  assume_role_policy = data.template_file.lambda_assume_role_policy.rendered
}

#IAM Policy to manage the permissions associated with the IAM role
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = var.tf_lambda_iam_policy
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = data.template_file.lambda_iam_policy.rendered
}

#attach both IAM Policy and IAM Role to each other:
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn

}

resource "aws_lambda_permission" "lambda_allow_cognito" {
  statement_id  = "lambda-allow-cognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation_lambda.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.userpool.arn
}

resource "aws_lambda_function" "post_confirmation_lambda" {
  filename      = data.archive_file.post_confirmation_lambda_zip.output_path
  function_name = "post_confirmation_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.post_confirmation_lambda_zip.output_base64sha256
  runtime          = "nodejs18.x"
  layers = [
    aws_lambda_layer_version.lambda_deps_layer.arn,
    # aws_lambda_layer_version.lambda_utils_layer.arn
  ]

  environment {
    variables = {
      # STRIPE_SECRET = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)[var.stripe_secret_key]
      STRIPE_SECRET = data.hcp_vault_secrets_secret.stripeSecret.secret_value
    }
  }
}

resource "aws_lambda_layer_version" "lambda_deps_layer" {
  layer_name = "shared_deps"
  s3_bucket  = aws_s3_bucket.dev_movie_auth_bucket.id         #conflicts with filename
  s3_key     = aws_s3_object.lambda_deps_layer_s3_storage.key #conflicts with filename
  // If using s3_bucket or s3_key, do not use filename, as they conflict
  # filename         = data.archive_file.deps_layer_code_zip.output_path
  source_code_hash = data.archive_file.deps_layer_code_zip.output_base64sha256

  compatible_runtimes = ["nodejs18.x"]
  depends_on = [
    aws_s3_object.lambda_deps_layer_s3_storage,
  ]
}

# resource "aws_lambda_layer_version" "lambda_utils_layer" {
#   layer_name = "shared_utils"
#   s3_bucket  = aws_s3_bucket.dev_movie_auth_bucket.id          #conflicts with filename
#   s3_key     = aws_s3_object.lambda_utils_layer_s3_storage.key #conflicts with filename
#   # filename         = data.archive_file.utils_layer_code_zip.output_path
#   source_code_hash = data.archive_file.utils_layer_code_zip.output_base64sha256

#   compatible_runtimes = ["nodejs18.x"]
#   depends_on = [
#     aws_s3_object.lambda_utils_layer_s3_storage,
#   ]
# }
# Create a bucket to store the lambda layer
resource "aws_s3_bucket" "dev_movie_auth_bucket" {
  bucket = "movie-authentication-bucket"

  tags = {
    Name        = "My movies_authentication dev bucket"
    Environment = "dev"
  }
}
//applies an s3 bucket acl resource to s3_backend
resource "aws_s3_bucket_acl" "s3_acl" {
  bucket     = aws_s3_bucket.dev_movie_auth_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.dev_movie_auth_bucket_acl_ownership]
}
# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "dev_movie_auth_bucket_acl_ownership" {
  bucket = aws_s3_bucket.dev_movie_auth_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

# resource "aws_s3_object" "lambda_utils_layer_s3_storage" {
#   bucket = aws_s3_bucket.dev_movie_auth_bucket.id
#   key    = var.utils_layer_storage_key
#   source = data.archive_file.utils_layer_code_zip.output_path

#   # The filemd5() function is available in Terraform 0.11.12 and later
#   # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
#   # etag = "${md5(file("path/to/file"))}"
#   etag = data.archive_file.utils_layer_code_zip.output_base64sha256
#   depends_on = [
#     data.archive_file.utils_layer_code_zip,
#   ]
# }

resource "aws_s3_object" "lambda_deps_layer_s3_storage" {
  bucket = aws_s3_bucket.dev_movie_auth_bucket.id
  key    = var.deps_layer_storage_key
  source = data.archive_file.deps_layer_code_zip.output_path

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = data.archive_file.deps_layer_code_zip.output_base64sha256
  depends_on = [
    data.archive_file.deps_layer_code_zip,
  ]
}
