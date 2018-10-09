provider "aws" {
  region = "${ var.region }"
}

provider "aws" {
  alias  = "dr"
  region = "${ var.dr_region }"
}
