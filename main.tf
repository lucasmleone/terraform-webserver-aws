resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lab-vpc"
  }
}

resource "aws_subnet" "lab_public_subnet1" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-subnet-public1-us-east-1a"
  }
}

resource "aws_subnet" "lab_private_subnet1" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "lab-subnet-private1-us-east-1a"
  }
}

// internet gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "lab-igw"
  }
}
//elastic ip
resource "aws_eip" "lab_nat_eip" {
  domain   = "vpc"

  tags = {
    Name = "lab-nat-eip"
  }
}
// nat gateway
resource "aws_nat_gateway" "lab-nat-gateway" {
  allocation_id = aws_eip.lab_nat_eip.id
  subnet_id     = aws_subnet.lab_public_subnet1.id

  tags = {
    Name = "lab-nat-public1-us-east-1a"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.lab_igw]
}

// Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }
  tags = {
    Name = "lab-rtb-public"
  }
}

// Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.lab_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab-nat-gateway.id
  }
  tags = {
    Name = "lab-rtb-private1-us-east-1a"
  }
}

# Route Table Association Private
resource "aws_route_table_association" "lab_rt_assoc_private" {
  subnet_id      = aws_subnet.lab_private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

# Route Table Association Public
resource "aws_route_table_association" "lab_rt_assoc_public" {
  subnet_id      = aws_subnet.lab_public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "lab_public_subnet2" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-subnet-public2"
  }
}

resource "aws_subnet" "lab_private_subnet2" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"

  tags = {
    Name = "lab-subnet-private2"
  }
}

# Route Table Association Private
resource "aws_route_table_association" "lab_rt_assoc_private2" {
  subnet_id      = aws_subnet.lab_private_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Route Table Association Public
resource "aws_route_table_association" "lab_rt_assoc_public2" {
  subnet_id      = aws_subnet.lab_public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_security_group" "allow_http" {
  name        = "Web Security Group"
  description = "Enable HTTP access"
  vpc_id      = aws_vpc.lab_vpc.id

  tags = {
    Name = "Web Security Group"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_instance" "web-server1" {
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t2.micro"
  key_name = "vockey"
  subnet_id     = aws_subnet.lab_public_subnet2.id
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  associate_public_ip_address = true
  user_data     = <<EOF
#!/bin/bash
# Install Apache Web Server and PHP
dnf install -y httpd wget php mariadb105-server
# Download Lab files
wget https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-100-ACCLFO-2/2-lab2-vpc/s3/lab-app.zip
unzip lab-app.zip -d /var/www/html/
# Turn on web server
chkconfig httpd on
service httpd start
EOF

  tags = {
    Name = "Web Server 1"
  }
}