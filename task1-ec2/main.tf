provider "aws" {
  region = var.region
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023.id

  # Instances flagged protected=true get their own resource block, because a
  # lifecycle block cannot be switched on/off per for_each instance.
  protected_instances = { for k, v in var.instances : k => v if v.protected }
  standard_instances  = { for k, v in var.instances : k => v if !v.protected }

  common_tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_instance" "standard" {
  for_each = local.standard_instances

  ami           = local.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type = each.value.volume_type
    volume_size = each.value.volume_size
  }

  tags = merge(local.common_tags, { Name = each.key })
}

resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami           = local.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type = each.value.volume_type
    volume_size = each.value.volume_size
  }

  tags = merge(local.common_tags, { Name = each.key })

  lifecycle {
    prevent_destroy = true
  }
}
