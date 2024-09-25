resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
} 
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "public"
  }
  map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "egw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main"
  }
}
resource "aws_route_table" "public_rout" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.egw.id 
  }
}
resource "aws_route_table_association" "publicattach" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rout.id

}
resource "aws_ebs_volume" "exampleBastion" {
  availability_zone = "eu-central-1a"
  size              = 4

  tags = {
    Name = "Hello bastion"
  }
}
resource "aws_ebs_snapshot" "snapshot_bastion" {
  volume_id = aws_ebs_volume.exampleBastion.id

  tags = {
    Name = "HelloWorld_snap"
  }
}
resource "aws_ami" "ami_1" {
  name                = "terraform-example2"
  virtualization_type = "hvm"
  root_device_name    = "/dev/xvda"
  imds_support        = "v2.0" 
  ebs_block_device {
    device_name = "/dev/xvda"
    volume_size = 4
  snapshot_id = aws_ebs_snapshot.snapshot_bastion.id
  }
}
resource "aws_security_group" "securitygroup_bastion" {
  name        = "bastion-sg"
  description = "Security group for the Bastion Host"
  vpc_id = aws_vpc.vpc.id
  ingress {
    description = "Allow ping from any specify IP"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"

    cidr_blocks = ["0.0.0.0/0"]  
  }
    ingress {
    description      = "Allow SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["102.190.145.239/32"]  
    }
   ingress {
    description      = "Allow http traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  
    }
       ingress {
    description      = "Allow http traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["3.120.181.40/29"]  
    }
}
resource "tls_private_key" "ssh_key3" {
  algorithm = "RSA"        
  rsa_bits  = 2048 
}
resource "aws_key_pair" "ssh_key3" {
  key_name   = "bastion-key3"
  public_key = tls_private_key.ssh_key3.public_key_openssh 
}

resource "local_file" "private_key3" {
  filename = "${path.module}/bastion-key.pem" 
  content  = tls_private_key.ssh_key3.private_key_pem 
} 
resource "aws_instance" "bastionhost" {
  ami           = "ami-0a0d2ca99b40eb592"
  instance_type = "t2.micro"
  tags = {
    Name = "BastionHost"
  }
vpc_security_group_ids = [aws_security_group.securitygroup_bastion.id]
subnet_id = aws_subnet.public_subnet.id
 key_name      = aws_key_pair.ssh_key3.key_name 

}

resource "aws_eip" "web_ip" {
  instance = aws_instance.bastionhost.id
}