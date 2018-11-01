provider "aws" {
  region  = "(AWS_REGION)"
  version = "~> 1.41"
  alias   = "default"
}

provider "local" {
  version = "~> 1.0"
  alias   = "default"
}

provider "null" {
  version = "~> 1.0"
  alias   = "default"
}

provider "template" {
  version = "~> 1.0"
  alias   = "default"
}

provider "tls" {
  version = "~> 1.0"
  alias   = "default"
}

terraform {
  backend "s3" {
    bucket = "gds-re-(AWS_ACCOUNT_NAME)-terraform-state"
    region = "eu-west-2"
    key    = "(CLUSTER_NAME).(AWS_ACCOUNT_NAME).(CLOUD).(SYSTEM_DOMAIN)/cluster.tfstate"
  }
}

module "cluster" {
  source = "git::https://github.com/alphagov/gsp-typhoon//aws/container-linux/kubernetes?ref=v1.12.2"

  providers = {
    aws      = "aws.default"
    local    = "local.default"
    null     = "null.default"
    template = "template.default"
    tls      = "tls.default"
  }

  # AWS
  cluster_name = "(CLUSTER_NAME)"
  dns_zone     = "(ZONE_NAME)"
  dns_zone_id  = "(ZONE_ID)"

  # configuration
  ssh_authorized_key = "(PUBLIC_SSH_KEY)"
  asset_dir          = "secrets"

  # optional
  worker_count = 2
  worker_type  = "t2.medium"
}

resource "aws_route53_record" "ingress" {
  providers = {
    aws = "aws.default"
  }

  zone_id = "(ZONE_ID)"
  name    = "*.(ZONE_NAME)"
  type    = "CNAME"
  ttl     = "300"
  records = ["${module.cluster.ingress_dns_name}"]
}
