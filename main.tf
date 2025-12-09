terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------
# Use default VPC and subnets
# ---------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -------------------------------------------------
# Security Group: allow SSH + Postgres between EC2/RDS
# -------------------------------------------------

resource "aws_security_group" "demo_sg" {
  name        = "ec2-postgres-sg"
  description = "Security group for EC2 with PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  # SSH from anywhere (for demo; restrict to your IP in real life)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL from anywhere (for demo; restrict later)
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-postgres-sg"
  }
}



# ------------
# EC2 instance
# ------------
resource "aws_instance" "demo_ec2" {
  ami                         = "ami-0b8d527345fdace59"
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.demo_sg.id]
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnets.default.ids[0]

  # Recreate instance when user_data changes
  user_data_replace_on_change = true

  # Cloud-init script for Ubuntu: install & configure PostgreSQL
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update packages
              apt-get update -y

              # Install PostgreSQL server and client
              DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib

              # Find config files dynamically (works across versions)
              PG_CONF=$(find /etc/postgresql -name postgresql.conf | head -n 1)
              PG_HBA=$(find /etc/postgresql -name pg_hba.conf | head -n 1)

              # Allow remote connections (for demo only; not for production)
              if [ -n "$PG_CONF" ]; then
                sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
              fi

              if [ -n "$PG_HBA" ]; then
                echo "host all all 0.0.0.0/0 md5" >> "$PG_HBA"
              fi

              # Restart PostgreSQL to apply changes
              systemctl restart postgresql

              # Create DB user and database (ignore if they already exist)
              sudo -u postgres psql -c "CREATE USER appuser WITH PASSWORD 'AppUser123!';" || true
              sudo -u postgres psql -c "CREATE DATABASE appdb OWNER appuser;" || true
              EOF

  tags = {
    Name = "terraform-ec2-postgres"
  }
}
