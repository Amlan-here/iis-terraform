terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws"{
    region = "eu-west-1"
}

resource "aws_vpc" "main"{
    cidr_block = "10.203.1.0/26"

    tags = { 
        Name = "iis-dose-vpc"
    }
}
resource "aws_subnet" "app_subnet"{
    vpc_id = aws_vpc.main.id 
    cidr_block = "10.203.1.0/27"
    availability_zone = "eu-west-1a"

    tags = {
        Name = "iis-dose-app-subnet"
    }
}
resource "aws_security_group" "app_sg"{
    name = "iis-dose-app-sg"
    description = "Security group for IIS-Dose Windows Server"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 3389
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTPS access"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "iis-dose-app-sg"
    }
}
data "aws_ami" "windows_2022" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["Windows_Server-2022-English-Full-Base-*"]
    }
}
resource "aws_instance" "iis_dose" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  private_ip             = "10.203.1.15"
  key_name               = "iis-dose-key"
  associate_public_ip_address = true

  tags = {
    Name = "iis-dose-instance"
  }
}
resource "aws_ebs_volume" "extra_storage" {
    availability_zone = "eu-west-1a"
    size = 5
    type = "gp3"

    tags = {
        Name = "iis-dose-extra-volume"
    }
}
resource "aws_volume_attachment" "extra_storage_attach" {
    device_name = "/dev/xvdf"
    volume_id = aws_ebs_volume.extra_storage.id
    instance_id = aws_instance.iis_dose.id
}
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "iis-dose-igw"
    }
}
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "iis-dose-public-rt"
    }
}
resource "aws_route_table_association" "public_rt_assoc" {
    subnet_id      = aws_subnet.app_subnet.id
    route_table_id = aws_route_table.public_rt.id
}