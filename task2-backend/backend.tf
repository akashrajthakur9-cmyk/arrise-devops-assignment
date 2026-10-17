# Drop this file into task1-ec2/ after running the bootstrap in ./bootstrap
# once. The bucket name must be globally unique - change it to your own.
terraform {
  backend "s3" {
    bucket         = "akashraj-devops-assignment-tfstate"
    key            = "task1-ec2/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
