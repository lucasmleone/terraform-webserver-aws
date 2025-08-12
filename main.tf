# VPC principal: bloque IP y soporte DNS habilitado
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lab-vpc"
  }
}

# Subred pública AZ1: asigna IP pública automáticamente
resource "aws_subnet" "lab_public_subnet1" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-subnet-public1-us-east-1a"
  }
}

# Subred privada AZ1: sin IP pública
resource "aws_subnet" "lab_private_subnet1" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "lab-subnet-private1-us-east-1a"
  }
}

// Internet Gateway: conecta la VPC a Internet
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "lab-igw"
  }
}

// Elastic IP: dirección estática para NAT Gateway
resource "aws_eip" "lab_nat_eip" {
  domain   = "vpc"

  tags = {
    Name = "lab-nat-eip"
  }
}

// NAT Gateway AZ1: permite que subredes privadas accedan a Internet
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

// Tabla de rutas pública: 0.0.0.0/0 -> IGW
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

// Tabla de rutas privada: 0.0.0.0/0 -> NAT Gateway
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

# Asociación de rutas: enlaza subred privada AZ1 a su tabla
resource "aws_route_table_association" "lab_rt_assoc_private" {
  subnet_id      = aws_subnet.lab_private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

# Asociación de rutas: enlaza subred pública AZ1 a su tabla
resource "aws_route_table_association" "lab_rt_assoc_public" {
  subnet_id      = aws_subnet.lab_public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Subred pública AZ2
resource "aws_subnet" "lab_public_subnet2" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-subnet-public2"
  }
}

# Subred privada AZ2
resource "aws_subnet" "lab_private_subnet2" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"

  tags = {
    Name = "lab-subnet-private2"
  }
}

# Asociación de rutas: enlaza subred privada AZ2
resource "aws_route_table_association" "lab_rt_assoc_private2" {
  subnet_id      = aws_subnet.lab_private_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Asociación de rutas: enlaza subred pública AZ2
resource "aws_route_table_association" "lab_rt_assoc_public2" {
  subnet_id      = aws_subnet.lab_public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group HTTP: permite tráfico entrante por puerto 80
resource "aws_security_group" "allow_http" {
  name        = "Web Security Group"
  description = "Enable HTTP access"
  vpc_id      = aws_vpc.lab_vpc.id

  tags = {
    Name = "Web Security Group"
  }
}

# Egress Rule: todo el tráfico de salida está permitido
resource "aws_vpc_security_group_egress_rule" "allow_all_egress" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Ingress Rule: HTTP desde cualquier IPv4 (80/tcp)
resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# EC2 Instance: servidor web con Apache, PHP y contenido demo
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