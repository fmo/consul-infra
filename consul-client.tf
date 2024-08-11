provider "aws" {
  region = "eu-central-1"
}

resource "aws_instance" "consul_client" {
  ami           = "ami-0e872aee57663ae2d"
  instance_type = "t2.micro"

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y wget unzip

    # Download and install Consul
    CONSUL_VERSION="1.11.0"
    wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
    unzip consul_${CONSUL_VERSION}_linux_amd64.zip
    sudo mv consul /usr/local/bin/
    sudo chmod +x /usr/local/bin/consul

    # Create Consul configuration directory and files
    sudo mkdir -p /etc/consul.d /var/consul
    sudo tee /etc/consul.d/consul.hcl > /dev/null <<-EOC
    data_dir = "/var/consul"
    bind_addr = "$(curl http://169.254.169.254/latest/meta-data/local-ipv4)"
    client_addr = "0.0.0.0"
    server = false
    retry_join = ["<Consul Server Private IP>"]  # Replace with the Consul server's private IP
    EOC

    # Create Consul service
    sudo tee /etc/systemd/system/consul.service > /dev/null <<-EOS
    [Unit]
    Description=Consul Agent
    Requires=network-online.target
    After=network-online.target

    [Service]
    ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
    ExecReload=/bin/kill -HUP $MAINPID
    KillMode=process
    Restart=on-failure
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    EOS

    # Enable and start the Consul service
    sudo systemctl enable consul
    sudo systemctl start consul
  EOF

  tags = {
    Name = "ConsulClient"
  }

  # Define a security group to allow necessary traffic
  vpc_security_group_ids = [aws_security_group.consul_sg.id]
}

# Security Group allowing SSH, HTTP, and Consul ports
resource "aws_security_group" "consul_sg" {
  name        = "consul-client-sg"
  description = "Allow SSH, HTTP, and Consul traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
