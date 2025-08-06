

data "aws_ami" "snort_server" {
  count       = (var.snort_server.snort_server == "1") ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "snort_sensor" {
  count                       = var.snort_server.snort_server == "1" ? 1 : 0
  ami                         = data.aws_ami.snort_server[0].id
  instance_type               = "m5.2xlarge"
  key_name                    = var.general.key_name
  subnet_id                   = var.aws.use_public_ips == "0" ? var.aws.private_subnet_1 : var.ec2_subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  private_ip                  = var.snort_server.snort_server_ip
  associate_public_ip_address = var.aws.use_public_ips

  root_block_device {
    volume_type           = "gp3"
    volume_size           = "120"
    delete_on_termination = "true"
  }

  tags = merge({
    Name = "ar-snort-${var.general.key_name}-${var.general.attack_range_name}"
    },
    var.tags
  )

  provisioner "remote-exec" {
    inline = ["echo booted"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = var.aws.use_public_ips == "1" ? aws_instance.snort_sensor[0].public_ip : aws_instance.snort_sensor[0].private_ip
      private_key = file(var.aws.private_key_path)
    }
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command     = <<-EOT
      cat <<EOF > vars/snort_vars.json
      {
        "ansible_python_interpreter": "/usr/bin/python3",
        "general": ${jsonencode(var.general)},
        "splunk_server": ${jsonencode(var.splunk_server)},
        "edge_processor": ${jsonencode(var.edge_processor)},
        "snort_server": ${jsonencode(var.snort_server)},
      }
      EOF
    EOT
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key '${var.aws.private_key_path}' -i '${var.aws.use_public_ips == "1" ? aws_instance.snort_sensor[0].public_ip : aws_instance.snort_sensor[0].private_ip},' snort_server.yml -e @vars/snort_vars.json"
  }
}

resource "aws_eip" "snort_ip" {
  count    = (var.snort_server.snort_server == "1") && (var.aws.use_elastic_ips == "1") ? 1 : 0
  instance = aws_instance.snort_sensor[0].id
}
