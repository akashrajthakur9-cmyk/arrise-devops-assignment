variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Value for the Environment tag on every instance"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Value for the Owner tag on every instance"
  type        = string
  default     = "akashraj"
}

variable "ami_id" {
  description = "Optional AMI override. When null, the latest Amazon Linux 2023 AMI is looked up."
  type        = string
  default     = null
}

# Single input variable that drives all 5 instances.
# Key pair names must already exist in the target account/region - replace
# these placeholder names with real ones before applying.
variable "instances" {
  description = "Map of instance name => config. Add/remove entries to scale the fleet."
  type = map(object({
    instance_type = string
    volume_type   = string
    volume_size   = number
    key_name      = string
    protected     = optional(bool, false)
  }))
  default = {
    web-1 = {
      instance_type = "t3.micro"
      volume_type   = "gp3"
      volume_size   = 20
      key_name      = "devops-key-1"
    }
    web-2 = {
      instance_type = "t3.small"
      volume_type   = "gp3"
      volume_size   = 30
      key_name      = "devops-key-2"
    }
    app = {
      instance_type = "t3.medium"
      volume_type   = "gp2"
      volume_size   = 40
      key_name      = "devops-key-3"
    }
    worker = {
      instance_type = "m5.large"
      volume_type   = "gp3"
      volume_size   = 50
      key_name      = "devops-key-4"
    }
    db = {
      instance_type = "r5.large"
      volume_type   = "io2"
      volume_size   = 100
      key_name      = "devops-key-5"
      protected     = true
    }
  }
}
