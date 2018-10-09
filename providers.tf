provider "aws" {
  alias                   = "us-west"
  region                  = "us-west-2"
  shared_credentials_file = "${pathexpand("~/.aws/config")}"
  version                 = "~> 1.34"
}
