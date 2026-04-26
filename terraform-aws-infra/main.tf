resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TerraWeek-VPC"
  }
}
resource "aws_subnet" "main" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  tags = {
    Name = "Terraweek-Subnet"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "TerraWeek-IGW"
  }
}
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "TerraWeek-RT"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
	name 	    = "aws_sg"
	vpc_id      = aws_vpc.main.id
	tags = {
		Name = "TerraWeek-SG"
}
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ip" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
resource "aws_instance" "my_instance" {
        ami = "ami-0d76b909de1a0595d"
        instance_type = "t2.micro"
        subnet_id       = aws_subnet.main.id
        vpc_security_group_ids = [aws_security_group.main.id]
        associate_public_ip_address = true

	tags = {
    	  Name = "TerraWeek-Server"
 }
	lifecycle {
    create_before_destroy = true  # ← New EC2 ready before old one dies
  }
}

output "public_ip" {
  value = aws_instance.my_instance.public_ip
}
resource "aws_s3_bucket" "main" {
  depends_on = [aws_instance.my_instance]
  bucket = "raju-ki-bucket-3"
  tags = {
    Name = "Terraweek-Bucket"
  }
}

