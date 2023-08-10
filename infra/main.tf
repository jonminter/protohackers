provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region                   = "us-east-1"
}

resource "aws_vpc" "protohacker_solutions" {
  cidr_block = "10.0.0.0/16"

  tags = {
    App = "protohacker-solutions"
  }
}

resource "aws_subnet" "protohacker_solutions_public" {
  vpc_id            = aws_vpc.protohacker_solutions.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "protohacker_solutions" {
  vpc_id = aws_vpc.protohacker_solutions.id

  tags = {
    App = "protohacker-solutions"
  }
}

resource "aws_route_table" "protohacker_solutions_route_to_internet" {
  vpc_id = aws_vpc.protohacker_solutions.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.protohacker_solutions.id
  }

  tags = {
    Name = "route-to-internet"
    App  = "protohacker-solutions"
  }
}

resource "aws_route_table_association" "protohacker_solutions_public" {
  subnet_id      = aws_subnet.protohacker_solutions_public.id
  route_table_id = aws_route_table.protohacker_solutions_route_to_internet.id
}

resource "aws_security_group" "protohacker_solutions" {
  name        = "protohacker-solutions"
  description = "Allow TCP traffic to problem solution ports"
  vpc_id      = aws_vpc.protohacker_solutions.id
}

resource "aws_vpc_security_group_ingress_rule" "protohacker_solutions_ssh_rule" {
  security_group_id = aws_security_group.protohacker_solutions.id

  description = "SSH from My IP"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = "${var.my_ip_address}/32"
}

resource "aws_vpc_security_group_ingress_rule" "protohacker_solutions_problem0_rule" {
  security_group_id = aws_security_group.protohacker_solutions.id

  description = "Problem 0: Smoketest"
  from_port   = 10000
  to_port     = 10000
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}


resource "aws_vpc_security_group_egress_rule" "protohacker_solutions_outbound_rule" {
  security_group_id = aws_security_group.protohacker_solutions.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

data "aws_ami" "amazon_linux_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

data "aws_ami" "amazon_linux_x86" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

resource "aws_iam_role" "protohacker_solutions_ec2" {
  name = "protohacker-solutions-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "protohacker-download-problem-binary"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:HeadObject",
            "s3:GetObject"
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:s3:::protohacker-solutions/*"
          ]
        }
      ]
    })
  }
}

resource "aws_iam_instance_profile" "protohacker_solutions_instance_profile" {
  name = "protohacker-solutions-instance-profile"
  role = aws_iam_role.protohacker_solutions_ec2.name
}
resource "aws_instance" "protohacker_solutions" {
  ami           = data.aws_ami.amazon_linux_x86.id
  instance_type = "t3.nano"
  subnet_id     = aws_subnet.protohacker_solutions_public.id
  vpc_security_group_ids = [
    aws_security_group.protohacker_solutions.id
  ]
  iam_instance_profile = aws_iam_instance_profile.protohacker_solutions_instance_profile.name

  user_data = file("setup_host.sh")

  tags = {
    App = "protohacker-solutions"
  }
}

resource "aws_eip" "protohacker_solutions" {
  vpc = true

  tags = {
    App = "protohacker-solutions"
  }
}

resource "aws_s3_bucket" "protohacker_solutions" {
  bucket = "protohacker-solutions"

  tags = {
    App = "protohacker-solutions"
  }
}

resource "aws_eip_association" "protohacker_solutions_instance" {
  instance_id   = aws_instance.protohacker_solutions.id
  allocation_id = aws_eip.protohacker_solutions.id
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "protohacker_solutions_ssh" {
  name = "protohacker-solutions-ssh"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${var.sso_role_name}"
        }
      }
    ]
  })

  inline_policy {
    name = "protohacker-solutions-ssh"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DescribeInstances"
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances",
          ],
          Resource = "*"
        },
        {
          Sid    = "AllowSsh"
          Effect = "Allow"
          Action = [
            "ec2-instance-connect:SendSSHPublicKey",
          ],
          Resource = [
            aws_instance.protohacker_solutions.arn
          ]
        }
      ]
    })
  }

  tags = {
    App = "protohacker-solutions"
  }
}

output "instance_id" {
  value = aws_instance.protohacker_solutions.id
}

output "instance_ip" {
  value = aws_eip.protohacker_solutions.public_ip
}

output "ssh_role_arn" {
  value = aws_iam_role.protohacker_solutions_ssh.arn
}
