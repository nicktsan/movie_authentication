variable "region" {
  description = "AWS region"
  type        = string
}

variable "userpool_name" {
  description = "Name for cognito user pool"
  type        = string
}

variable "userpool_client_name" {
  description = "Name for cognito user pool client"
  type        = string
}

variable "userpool_domain" {
  description = "Domain of the cognito user pool"
  type        = string
}

variable "tf_lambda_iam_role" {
  description = "Name of the IAM role for the lambda function"
  type        = string
}

variable "userpool_client_callback_url" {
  description = "Callback url for the Cognito userpool client"
  type        = string
}

variable "tf_lambda_iam_policy" {
  description = "AWS IAM policy for lambda function"
  type        = string
}

variable "stripe_secrect_name" {
  description = "Name of the Stripe secret in Secrets manager"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Key of the stripe secret stored in secrets manager"
  type        = string
  sensitive   = true
}

variable "utils_layer_storage_key" {
  description = "Key of the S3 object that will store utils lambda layer"
  type        = string
}

variable "deps_layer_storage_key" {
  description = "Key of the S3 Object that will store deps lambda layer"
  type        = string
}
