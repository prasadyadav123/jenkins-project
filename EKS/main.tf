#VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb"               = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = 1
  }
}

#EKS

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_type = ["t3.medium"]
    }
  }

  enable_cluster_creator_admin_permissions = true



  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

#RDS

# Create a Security Group for RDS
resource "aws_security_group" "mariadb_sg" {
  vpc_id = module.vpc.vpc_id
  name        = "mariadb_security_group"
  description = "Allow MySQL inbound traffic"

  # Allow inbound MySQL access (default port 3306)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Update to restrict access as needed
  }

  # Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mariadb_sg"
  }
}

# Create a Subnet Group for RDS
resource "aws_db_subnet_group" "mariadb_subnet_group" {
  name        = "mariadb_subnet_group"
  description = "Subnet group for MariaDB"
  subnet_ids  = module.vpc.public_subnets # Replace with your subnet IDs

  tags = {
    Name = "mariadb_subnet_group"
  }
}

# Create the RDS instance for MariaDB
resource "aws_db_instance" "mariadb" {
  allocated_storage      = 20
  engine                 = "mariadb"
  engine_version         = "10.11.8" # Specify MariaDB version
  instance_class         = "db.t3.micro"
  identifier             = "mydb123"             # Database name
  username               = "admin"               # Master username
  password               = "password123"         # Master password
  db_subnet_group_name   = aws_db_subnet_group.mariadb_subnet_group.name
  vpc_security_group_ids = [aws_security_group.mariadb_sg.id]
  skip_final_snapshot    = true
  publicly_accessible = true

  tags = {
    Name = "MyMariaDBInstance"
  }
}
