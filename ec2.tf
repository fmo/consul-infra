provider "aws" {
  region = "eu-central-1"
}

resource "aws_instance" "order" {
  ami           = "ami-0e872aee57663ae2d"
  instance_type = "t2.micro"

  tags = {
    Name = "OrderInstance"
  }
}
