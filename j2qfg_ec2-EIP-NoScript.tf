#Creates the EC2 instances, attach roles and (but do not run the scripts as EIPs are used)
#owner: Alexandre Cezar
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Creates the Bastion Host for access to the environment
resource "aws_instance" "bastion" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = "pc-national-bank-ssh-${var.global_random_var}"
  tags = {
    Name      = "attack-vm_${var.global_random_var}"
    yor_name  = "bastion"
    yor_trace = "33b82023-5038-41a4-9c38-f37cf8eb5dba"
  }
  depends_on = [aws_vpc.demo-foundations-vpc]
  root_block_device {
    volume_size           = 8     # Change this to your desired root volume size (in GiB)
    volume_type           = "gp3" # Change this to your desired root volume type (gp2, gp3, io1, io2, etc.)
    delete_on_termination = true
    encrypted             = true
  }
  user_data = <<-EOF
              #!/bin/bash
              # Backup the original sshd_config file
              sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
              # Add Port 22 and Port 443 to the sshd_config file
              sudo bash -c 'echo "Port 22" >> /etc/ssh/sshd_config'
              sudo bash -c 'echo "Port 443" >> /etc/ssh/sshd_config'
              sudo bash -c 'echo "Port 80" >> /etc/ssh/sshd_config'
              # Restart the SSH service
              sudo systemctl restart sshd
              sudo bash -c 'echo "\$nrconf{restart} = '\''a'\'';" >> /etc/needrestart/needrestart.conf'
              sudo bash -c 'echo "\$nrconf{kernelhints} = '\''-1'\'';" >> /etc/needrestart/needrestart.conf'
              sudo apt-get update
              sudo apt-get install -y python3-pip
              pip3 install --upgrade pip
              pip3 install paramiko
              EOF
}

# Creates and Associates the Elastic IP to the Bastion Host
# resource "aws_eip" "bastion" {
#   instance = aws_instance.bastion.id
#   vpc      = true
#   tags = {
#   }
# }


# Creates the Bastion Host for access to the environment
resource "aws_instance" "exfil_bastion" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.exfil-public-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.exfil-ssh-security-group.id]
  associate_public_ip_address = true
  key_name                    = "pc-national-bank-ssh-${var.global_random_var}"
  tags = {
    Name      = "exfil-vm_${var.global_random_var}"
    yor_name  = "exfil_bastion"
    yor_trace = "e952d3f5-2c08-43e7-b28f-498d2707f5eb"
  }
  depends_on = [aws_vpc.exfil-vpc]
  root_block_device {
    volume_size           = 40    # Change this to your desired root volume size (in GiB)
    volume_type           = "gp3" # Change this to your desired root volume type (gp2, gp3, io1, io2, etc.)
    delete_on_termination = true
    encrypted             = true
  }
  user_data = <<-EOF
              #!/bin/bash
              # Backup the original sshd_config file
              sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
              # Add Port 22 and Port 443 to the sshd_config file
              sudo bash -c 'echo "Port 22" >> /etc/ssh/sshd_config'
              sudo bash -c 'echo "Port 443" >> /etc/ssh/sshd_config'
              sudo bash -c 'echo "Port 80" >> /etc/ssh/sshd_config'
              # Restart the SSH service
              sudo systemctl restart sshd
              sudo bash -c 'echo "\$nrconf{restart} = '\''a'\'';" >> /etc/needrestart/needrestart.conf'
              sudo bash -c 'echo "\$nrconf{kernelhints} = '\''-1'\'';" >> /etc/needrestart/needrestart.conf'
              sudo apt-get update
              sudo apt-get install -y python3-pip
              pip3 install --upgrade pip
              pip3 install paramiko
              EOF
}

# # Creates and Associates the Elastic IP to the Bastion Host
# resource "aws_eip" "exfil_bastion" {
#   instance = aws_instance.exfil_bastion.id
#   vpc      = true
#   tags = {
#   }
# }

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "pc-national-bank-key-pair" {
  key_name   = "pc-national-bank-ssh-${var.global_random_var}"
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create a pem to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./pc-national-bank-ssh-${var.global_random_var}.pem"
  }
  tags = {
    yor_name  = "pc-national-bank-key-pair"
    yor_trace = "2057be6d-9a35-4635-980f-23a0d198802c"
  }
}

# Creates the vulnerable instance that will trigger the Hyperion policies
resource "aws_instance" "vulnerable" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = var.vulnerable_instance_type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.vulnerable_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.demo-insecure-profile-eu2.name
  key_name                    = "pc-national-bank-ssh-${var.global_random_var}"
  tags = {
    Name      = "Sales and Trading ${var.global_random_var}"
    yor_name  = "vulnerable"
    yor_trace = "96b50571-1234-44a8-870e-40b45369dd52"
  }

  depends_on = [aws_vpc.demo-foundations-vpc]
  root_block_device {
    volume_size           = 40    # Change this to your desired root volume size (in GiB)
    volume_type           = "gp3" # Change this to your desired root volume type (gp2, gp3, io1, io2, etc.)
    delete_on_termination = true
    encrypted             = true
  }
}

# resource "aws_ebs_volume" "additional_disk" {
#   availability_zone = aws_instance.vulnerable.availability_zone
#   size              = 40
#   encrypted         = true
#   tags = {
#     Name = "Additional Disk for Sales and Trading ${var.global_random_var}"
#   }
# }

# resource "aws_volume_attachment" "additional_disk_attachment" {
#   device_name = "/dev/xvdf"
#   volume_id   = aws_ebs_volume.additional_disk.id
#   instance_id = aws_instance.vulnerable.id
# }

# # Creates and Associates the Elastic IP to the Vulnerable Host
# resource "aws_eip" "vulnerable" {
#   instance = aws_instance.vulnerable.id
#   vpc      = true
#   tags = {
#   }
# }


resource "aws_security_group" "bastion_sg" {
  name   = "bastion_sg_${var.global_random_var}"
  vpc_id = aws_vpc.demo-foundations-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.runner_whitelist, var.user_whitelist]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block, aws_subnet.private-subnet.cidr_block]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block, aws_subnet.private-subnet.cidr_block]
  }
  tags = {
    Name      = "demo-bastion-sg_${var.global_random_var}"
    yor_name  = "bastion_sg"
    yor_trace = "712108f3-0e49-47e8-9b77-f0cf92502076"
  }
}

resource "aws_security_group" "vulnerable_sg" {
  name   = "vulnerable_sg_${var.global_random_var}"
  vpc_id = aws_vpc.demo-foundations-vpc.id


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block, var.user_whitelist, var.runner_whitelist]
  }

  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block, var.user_whitelist, var.runner_whitelist]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.user_whitelist, var.runner_whitelist]
  }

  ingress {
    from_port   = 3606
    to_port     = 3606
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block]
  }
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private-subnet.cidr_block]
  }
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private-subnet.cidr_block]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "demo-vulnerable-sg_${var.global_random_var}"
    yor_name  = "vulnerable_sg"
    yor_trace = "29c8b33f-1899-4474-becb-a80cdf92807c"
  }
}

resource "aws_security_group" "internal_sg" {
  name   = "internal_sg_${var.global_random_var}"
  vpc_id = aws_vpc.demo-foundations-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public-subnet.cidr_block]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private-subnet.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [aws_subnet.private-subnet.cidr_block]
  }
  tags = {
    Name      = "demo-internal-sg_${var.global_random_var}"
    yor_name  = "internal_sg"
    yor_trace = "b08f86e3-726a-45a8-b7a9-f1da71fe3c49"
  }
}

output "instance_name" {
  value = aws_instance.vulnerable.tags["Name"]
}
