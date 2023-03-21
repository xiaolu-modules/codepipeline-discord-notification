variable "app_name" {
  description = "Lambda function name."
}

variable "environment" {
  description = "Environemnt like dev or prod."
}

variable "bot_name" {
  description = "Discord webhook bot name."
}

variable "pipeline_names" {
  description = "CodePipeline names"
  type        = list(any)
}

variable "discord_webhook_url" {
  description = "Webhook URL provided by Discord when configured Incoming Webhook."
}

variable "discord_channel" {
  description = "Discord channel where messages are going to be posted."
}

variable "region" {
  description = "Your AWS deployment region."
  default     = "us-east-1"
}

variable "relavent_stages" {
  description = "Stages for which you want to get notified (ie. 'SOURCE,BUILD,DEPLOY'). Defaults to all)"
  default     = "SOURCE,BUILD,DEPLOY"
}

variable "lambda_timeout" {
  default = "10"
}

variable "lambda_memory_size" {
  default = "128"
}
