module "networkModule" {
  source  = "./modules/network"
  general = var.general
  aws     = var.aws
}

module "splunk-server" {
  source                 = "./modules/splunk-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  aws                    = var.aws
  splunk_server          = var.splunk_server
  phantom_server         = var.phantom_server
  general                = var.general
  simulation             = var.simulation
  windows_servers        = var.windows_servers
  linux_servers          = var.linux_servers
  kali_server            = var.kali_server
  zeek_server            = var.zeek_server
  snort_server           = var.snort_server
  role_arn               = aws_iam_role.s3_access.arn
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags                   = local.tags
}

module "phantom-server" {
  source                 = "./modules/phantom-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  phantom_server         = var.phantom_server
  general                = var.general
  aws                    = var.aws
  splunk_server          = var.splunk_server
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
}

module "windows-server" {
  source                 = "./modules/windows"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  aws                    = var.aws
  windows_servers        = var.windows_servers
  simulation             = var.simulation
  zeek_server            = var.zeek_server
  snort_server           = var.snort_server
  edge_processor         = var.edge_processor
  splunk_server          = var.splunk_server
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags                   = local.tags
}

module "linux-server" {
  source                 = "./modules/linux-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  aws                    = var.aws
  zeek_server            = var.zeek_server
  snort_server           = var.snort_server
  edge_processor         = var.edge_processor
  linux_servers          = var.linux_servers
  simulation             = var.simulation
  splunk_server          = var.splunk_server
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags                   = local.tags
}

module "kali-server" {
  source                 = "./modules/kali-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  kali_server            = var.kali_server
  aws                    = var.aws
  tags                   = local.tags
}

module "nginx-server" {
  source                 = "./modules/nginx-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  nginx_server           = var.nginx_server
  aws                    = var.aws
  splunk_server          = var.splunk_server
}

module "zeek-server" {
  source                   = "./modules/zeek-server"
  vpc_security_group_ids   = module.networkModule.sg_vpc_id
  ec2_subnet_id            = module.networkModule.ec2_subnet_id
  general                  = var.general
  aws                      = var.aws
  zeek_server              = var.zeek_server
  edge_processor           = var.edge_processor
  windows_servers          = var.windows_servers
  windows_server_instances = module.windows-server.windows_servers
  linux_servers            = var.linux_servers
  linux_server_instances   = module.linux-server.linux_servers
  splunk_server            = var.splunk_server
  apache_server_instance   = module.apache_httpd.httpd_server
  tags                     = local.tags
}

module "snort-server" {
  source                   = "./modules/snort-server"
  vpc_security_group_ids   = module.networkModule.sg_vpc_id
  ec2_subnet_id            = module.networkModule.ec2_subnet_id
  general                  = var.general
  aws                      = var.aws
  snort_server             = var.snort_server
  edge_processor           = var.edge_processor
  windows_servers          = var.windows_servers
  windows_server_instances = module.windows-server.windows_servers
  linux_servers            = var.linux_servers
  linux_server_instances   = module.linux-server.linux_servers
  splunk_server            = var.splunk_server
  apache_server_instance   = module.apache_httpd.httpd_server
  tags                     = local.tags
}

module "caldera-server" {
  source                 = "./modules/caldera-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  caldera_server         = var.caldera_server
  aws                    = var.aws
  tags                   = local.tags
}

module "nlb_security_group" {
  source  = "./modules/nlb_security_group"
  general = var.general
  aws     = var.aws
  tags    = local.tags
}

module "elb_security_group" {
  source  = "./modules/elb_security_group"
  general = var.general
  aws     = var.aws
  tags    = local.tags
}

module "edge_processor" {
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  source                 = "./modules/edge_processor"
  general                = var.general
  aws                    = var.aws
  edge_processor         = var.edge_processor
  splunk_server          = var.splunk_server
  nlb_security_group_id  = module.nlb_security_group.id
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags                   = local.tags
}

module "network_load_balancer" {
  source                     = "./modules/nlb"
  general                    = var.general
  aws                        = var.aws
  edge_processor             = var.edge_processor
  nlb_security_group_id      = module.nlb_security_group.id
  edge-processor_instance_id = module.edge_processor.instance_id
  tags                       = local.tags
}

module "apache_httpd" {
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  source                 = "./modules/apache/httpd"
  general                = var.general
  aws                    = var.aws
  httpd_server           = var.httpd_server
  splunk_server          = var.splunk_server
  edge_processor         = var.edge_processor
  elb_security_group_id  = module.elb_security_group.id
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags                   = local.tags
}

module "application_load_balancer" {
  source                   = "./modules/elb"
  general                  = var.general
  aws                      = var.aws
  httpd_server             = var.httpd_server
  elb_security_group_id    = module.elb_security_group.id
  apache-httpd_instance_id = module.apache_httpd.instance_id
  tags                     = local.tags
}

module "route53" {
  source       = "./modules/route53"
  aws          = var.aws
  general      = var.general
  alb_dns_name = module.application_load_balancer.dns_name
  nlb_dns_name = module.network_load_balancer.dns_name
}


module "waf" {
  source              = "./modules/waf-regional"
  waf_prefix          = "${var.general.name_prefix}-${var.general.attack_range_name}"
  enable_logging      = true
  log_destination_arn = module.firehose.kinesis_firehose_arn
  resource_arn        = [module.application_load_balancer.arn]
  tags                = local.tags
  custom_csrf_token = [
    {
      field    = "x-twilio-signature"
      size     = 28
      operator = "GT"
    }
  ]
}

resource "aws_s3_bucket" "s3" {
  bucket        = "${var.general.name_prefix}-${var.general.attack_range_name}-waf-backup-${var.aws.region}"
  force_destroy = true
  tags          = local.tags
}

resource "aws_kms_key" "backup_key" {
  description             = "${var.general.name_prefix}-${var.general.attack_range_name}-kms-key"
  deletion_window_in_days = 7
  tags                    = local.tags
}

module "firehose" {
  source                = "./modules/firehose"
  general               = var.general
  waf                   = var.waf
  destination           = "splunk"
  input_source          = "waf"
  s3_backup_bucket_arn  = aws_s3_bucket.s3.arn
  s3_backup_kms_key_arn = aws_kms_key.backup_key.arn
  tags                  = local.tags
}
