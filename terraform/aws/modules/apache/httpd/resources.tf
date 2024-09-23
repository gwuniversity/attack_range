data "aws_ami" "httpd_server" {
  count       = (var.httpd_server.httpd_server == "1") ? 1 : 0
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

resource "aws_instance" "httpd_server" {
  count                  = var.httpd_server.httpd_server == "1" ? 1 : 0
  ami                    = data.aws_ami.httpd_server[0].id
  instance_type          = "t3.small"
  key_name               = var.general.key_name
  subnet_id              = var.aws.private_subnet_id
  vpc_security_group_ids = [var.vpc_security_group_ids]
  iam_instance_profile   = var.instance_profile_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = "120"
    delete_on_termination = "true"
  }

  tags = {
    Name = "ar-httpd-${var.general.key_name}-${var.general.attack_range_name}"
  }
  provisioner "remote-exec" {
    inline = ["echo booted"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.private_ip
      private_key = file(var.aws.private_key_path)
    }
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command     = <<-EOT
      cat <<EOF > vars/httpd_vars.json
      {
        "ansible_python_interpreter": "/usr/bin/python3",
        "general": ${jsonencode(var.general)},
        "aws": ${jsonencode(var.aws)},
        "splunk_server": ${jsonencode(var.splunk_server)},
        "httpd_server": ${jsonencode(var.httpd_server)},
      }
      EOF
    EOT
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key ${var.aws.private_key_path} -i '${self.private_ip},' httpd_server.yml -e @vars/httpd_vars.json"
  }

}
