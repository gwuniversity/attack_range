module "networkModule" {
  source  = "./modules/network"
  general = var.general
  aws     = var.aws
}

# Deploy AutoMirror serverless application
resource "aws_serverlessapplicationrepository_cloudformation_stack" "automirror" {
  name           = "serverlessrepo-AutoMirror"
  application_id = "arn:aws:serverlessrepo:us-east-1:216624486486:applications/AutoMirror"
  capabilities   = ["CAPABILITY_IAM"]
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
  source                 = "./modules/zeek-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  aws                    = var.aws
  zeek_server            = var.zeek_server
  splunk_server          = var.splunk_server
  edge_processor         = var.edge_processor
  tags                   = local.tags
}

module "snort-server" {
  source                 = "./modules/snort-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  aws                    = var.aws
  snort_server           = var.snort_server
  splunk_server          = var.splunk_server
  edge_processor         = var.edge_processor
  tags                   = local.tags
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
  zeek_server                = var.zeek_server
  snort_server               = var.snort_server
  nlb_security_group_id      = module.nlb_security_group.id
  edge-processor_instance_id = module.edge_processor.instance_id
  zeek_network_interface_id  = module.zeek-server.network_interface_id
  snort_network_interface_id = module.snort-server.network_interface_id
  tags                       = local.tags
}

module "windows-server" {
  source                 = "./modules/windows"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  aws                    = var.aws
  zeek_server            = var.zeek_server
  snort_server           = var.snort_server
  windows_servers        = var.windows_servers
  simulation             = var.simulation
  splunk_server          = var.splunk_server
  caldera_server         = var.caldera_server
  edge_processor         = var.edge_processor
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags = merge(local.tags, {
    Mirror          = "True"
    "Mirror-Target" = module.network_load_balancer.traffic_mirror_target_id
    "Mirror-Filter" = module.network_load_balancer.traffic_mirror_filter_id
  })
}

module "linux-server" {
  source                 = "./modules/linux-server"
  vpc_security_group_ids = module.networkModule.sg_vpc_id
  ec2_subnet_id          = module.networkModule.ec2_subnet_id
  general                = var.general
  aws                    = var.aws
  zeek_server            = var.zeek_server
  snort_server           = var.snort_server
  linux_servers          = var.linux_servers
  simulation             = var.simulation
  splunk_server          = var.splunk_server
  caldera_server         = var.caldera_server
  edge_processor         = var.edge_processor
  instance_profile_name  = aws_iam_instance_profile.s3_access.name
  tags = merge(local.tags, {
    Mirror          = "True"
    "Mirror-Target" = module.network_load_balancer.traffic_mirror_target_id
    "Mirror-Filter" = module.network_load_balancer.traffic_mirror_filter_id
  })
}

