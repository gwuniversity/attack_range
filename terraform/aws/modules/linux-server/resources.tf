

data "aws_ami" "linux_server" {
  count       = length(var.linux_servers)
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

resource "aws_instance" "linux_server" {
  count                       = length(var.linux_servers)
  ami                         = data.aws_ami.linux_server[count.index].id
  instance_type               = "t3.xlarge"
  key_name                    = var.general.key_name
  subnet_id                   = var.aws.use_public_ips == "0" ? var.aws.private_subnet_id : var.ec2_subnet_id
  vpc_security_group_ids      = [var.vpc_security_group_ids]
  iam_instance_profile        = var.instance_profile_name
  private_ip                  = "${var.aws.network_prefix}.${var.aws.first_dynamic_ip + 3 + count.index}"
  associate_public_ip_address = var.aws.use_public_ips

  root_block_device {
    volume_type           = "gp3"
    volume_size           = "60"
    delete_on_termination = "true"
  }

  tags = {
    Name = "ar-linux-${var.general.key_name}-${var.general.attack_range_name}-${count.index}"
  }

  provisioner "remote-exec" {
    inline = ["echo booted"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = var.aws.use_public_ips == "1" ? self.public_ip : self.private_ip
      private_key = file(var.aws.private_key_path)
    }
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command     = <<-EOT
      cat <<EOF > vars/linux_vars_${count.index}.json
      {
        "ansible_python_interpreter": "/usr/bin/python3",
        "general": ${jsonencode(var.general)},
        "aws": ${jsonencode(var.aws)},
        "splunk_server": ${jsonencode(var.splunk_server)},
        "linux_servers": ${jsonencode(var.linux_servers[count.index])},
        "simulation": ${jsonencode(var.simulation)},
      }
      EOF
    EOT
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key '${var.aws.private_key_path}' -i '${var.aws.use_public_ips == "1" ? self.public_ip : self.private_ip},' linux_server.yml -e @vars/linux_vars_${count.index}.json"
  }
}

resource "aws_eip" "linux_server_ip" {
  count    = (var.aws.use_elastic_ips == "1") ? length(var.linux_servers) : 0
  instance = aws_instance.linux_server[count.index].id
}
