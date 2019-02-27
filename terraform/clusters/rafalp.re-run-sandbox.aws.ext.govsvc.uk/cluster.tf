terraform {
  backend "s3" {
    bucket = "gds-re-run-sandbox-terraform-state"
    region = "eu-west-2"
    key    = "rafalp.run-sandbox.aws.ext.govsvc.uk/cluster.tfstate"
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_caller_identity" "current" {}

module "gsp-cluster" {
    source = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/gsp-cluster?ref=upgrade-flux"
    cluster_name = "rafalp"
    controller_count = 1
    controller_instance_type = "m5d.large"
    worker_count = 1
    worker_instance_type = "m5d.large"
    /* etcd_instance_type = "t3.medium" */
    dns_zone = "run-sandbox.aws.ext.govsandbox.uk"
    user_data_bucket_name = "gds-re-run-sandbox-terraform-state"
    user_data_bucket_region = "eu-west-2"
    k8s_tag = "v1.12.2"
    admin_role_arns = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/admin",
    ]
    gds_external_cidrs = [
      "213.86.153.212/32",
      "213.86.153.213/32",
      "213.86.153.214/32",
      "213.86.153.235/32",
      "213.86.153.236/32",
      "213.86.153.237/32",
      "85.133.67.244/32",
    ]
    addons = {
      ingress = 1
      monitoring = 1
      secrets = 1
      ci = 1
      splunk = 0
    }
}

module "eidas-ci-pipelines" {
  source = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/flux-release"

  namespace      = "${module.gsp-cluster.ci-system-release-name}-main"
  chart_git      = "https://github.com/alphagov/verify-eidas-pipelines.git"
  chart_ref      = "rafalp"
  chart_path     = "."
  cluster_name   = "${module.gsp-cluster.cluster-name}"
  cluster_domain = "${module.gsp-cluster.cluster-domain-suffix}"
  addons_dir     = "addons/${module.gsp-cluster.cluster-name}"
  values = <<HEREDOC
    harbor:
      keys:
        ci: "${module.gsp-cluster.notary-ci-private-key}"
        root: "${module.gsp-cluster.notary-root-private-key}"
      passphrase:
        delegation: "${module.gsp-cluster.notary-delegation-passphrase}"
        root: "${module.gsp-cluster.notary-root-passphrase}"
        snapshot: "${module.gsp-cluster.notary-snapshot-passphrase}"
        targets: "${module.gsp-cluster.notary-targets-passphrase}"
      password: "${module.gsp-cluster.harbor-password}"
HEREDOC
}

module "hello" {
  source = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/flux-release"

  namespace      = "hello"
  chart_git      = "https://github.com/alphagov/gsp-example.git"
  chart_ref      = "staging"
  chart_path     = "."
  cluster_name   = "${module.gsp-cluster.cluster-name}"
  cluster_domain = "${module.gsp-cluster.cluster-domain-suffix}"
  addons_dir     = "addons/${module.gsp-cluster.cluster-name}"
  values = <<HEREDOC
    ingress:
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
      paths:
        - "/"
      hosts:
        - "hello.${module.gsp-cluster.cluster-domain-suffix}"
      tls:
      - secretName: hello-tls
        hosts:
        - "hello.${module.gsp-cluster.cluster-domain-suffix}"
HEREDOC
}

output "bootstrap-base-userdata-source" {
    value = "${module.gsp-cluster.bootstrap-base-userdata-source}"
}

output "bootstrap-base-userdata-verification" {
    value = "${module.gsp-cluster.bootstrap-base-userdata-verification}"
}

output "user-data-bucket-name" {
    value = "${module.gsp-cluster.user_data_bucket_name}"
}

output "user-data-bucket-region" {
    value = "${module.gsp-cluster.user_data_bucket_region}"
}

output "cluster-name" {
    value = "${module.gsp-cluster.cluster-name}"
}

output "controller-security-group-ids" {
    value = ["${module.gsp-cluster.controller-security-group-ids}"]
}

output "bootstrap-subnet-id" {
    value = "${module.gsp-cluster.bootstrap-subnet-id}"
}

output "controller-instance-profile-name" {
    value = "${module.gsp-cluster.controller-instance-profile-name}"
}

output "apiserver-lb-target-group-arn" {
    value = "${module.gsp-cluster.apiserver-lb-target-group-arn}"
}

output "dns-service-ip" {
    value = "${module.gsp-cluster.dns-service-ip}"
}

output "cluster-domain-suffix" {
    value = "${module.gsp-cluster.cluster-domain-suffix}"
}

output "k8s-tag" {
    value = "${module.gsp-cluster.k8s_tag}"
}

output "kubelet-kubeconfig" {
    value = "${module.gsp-cluster.kubelet-kubeconfig}"
    sensitive = true
}

output "admin-kubeconfig" {
    value = "${module.gsp-cluster.admin-kubeconfig}"
}

output "kube-ca-crt" {
    value = "${module.gsp-cluster.kube-ca-crt}"
}

output "github-deployment-public-key" {
    value = "${module.gsp-cluster.github-deployment-public-key}"
}