terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}
provider "aws" {
  profile = "default"
  region  = "us-west-2"
}


# base initialization
resource "aws_vpc" "primary_vpc" {
    cidr_block = "7.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "forLab9"
    }
}

resource "aws_subnet" "subnet_1" {
    vpc_id = aws_vpc.primary_vpc.id
    cidr_block = "7.0.0.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2a"
    tags = {
        Name = "forLab9_1" 
    }
}

resource "aws_subnet" "subnet_2" {
    vpc_id = aws_vpc.primary_vpc.id
    cidr_block = "7.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-west-2b"
    tags = {
        Name = "forLab9_2" 
    }
}
# internet access
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.primary_vpc.id
}
# route table
resource "aws_route_table" "rtb" {
    vpc_id = aws_vpc.primary_vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id

    }
}

# assing rtb -> subnets
resource "aws_route_table_association" "subnet_1_asoc" {
    route_table_id = aws_route_table.rtb.id
    subnet_id = aws_subnet.subnet_1.id
}


resource "aws_route_table_association" "subnet_2_asoc" {
    route_table_id = aws_route_table.rtb.id
    subnet_id = aws_subnet.subnet_1.id
}

# security group
resource "aws_security_group" "sg" {
    name = "forLab9"
    vpc_id = aws_vpc.primary_vpc.id
    
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
}


# adds esc cluster
resource "aws_ecs_cluster" "cluster" {
  name = "lab9cluster"
  tags = {
      Name = "forLab9"
  }
}

# adds task definition
resource "aws_ecs_task_definition" "task" {
  family = "sample-fargate"
  container_definitions = file("container-def.json")
  memory = 512
  cpu = 256
  network_mode = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
}

# adds services
resource "aws_ecs_service" "service" {
  name = "sample"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count = 1
  launch_type = "FARGATE"
  network_configuration {
    assign_public_ip = true
    subnets = [aws_subnet.subnet_1.id]
    security_groups = [aws_security_group.sg.id]
  }
}