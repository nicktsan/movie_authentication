resource "aws_cognito_user_pool" "userpool" {
  name = "movie-userpool"

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
}

resource "aws_cognito_user_pool_client" "userpool_client" {
  name                         = "movie-userpool-client"
  user_pool_id                 = aws_cognito_user_pool.userpool.id
  supported_identity_providers = ["COGNITO"]
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
