provider "aws" {
  alias                   = "us-west"
  region                  = "us-west-2"
  profile                 = "${var.aws_profile}"
  shared_credentials_file = "${pathexpand("~/.aws/config")}"
  version                 = "~> 1.34"
}
