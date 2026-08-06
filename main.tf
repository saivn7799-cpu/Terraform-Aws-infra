provider "aws" {}

# Variables for reusability and flexibility
variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}

# Creating a custom VPC with a name based on the environment prefix
resource "aws_vpc" "myapp-vpc" {
    cidr_block  = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

# Creating a subnet in the specified Availability Zone within the custom VPC
resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name = "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.env_prefix}-main-rtb"
  }
}

resource "aws_security_group" "myapp-sg" {
  name   = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  # Ingress rule for SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.my_ip]   # Only allow your specific IP (e.g., "85.246.32.98/32")
  }

  # Ingress rule for accessing Nginx web server (port 8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = [var.my_ip]  # Open to any IP address
  }

  # Egress rule to allow all outgoing traffic
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"          # "-1" means all protocols
    cidr_blocks     = [var.my_ip]
    prefix_list_ids = []
  }
  
  tags = {
    Name = "${var.env_prefix}-myapp-sg"
  }
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "aws-ssh-1"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type    # Choose an appropriate instance type
  subnet_id     = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  key_name      = aws_key_pair.ssh-key.key_name

  associate_public_ip_address = true
  availability_zone      = var.avail_zone
 
  user_data = file("entry-script.sh") 
  
  user_data_replace_on_change = true
  

  tags = {
    Name = "${var.env_prefix}-myapp-server"
  }
}