terraform {
    required_providers {    
        aws = {
            source = "hashicorp/aws"
            version = "5.50.0"
        }      
    }
       
}

provider "aws" {
  region = "ap-southeast-1"
  // access_key = if needed 
  //sercee_key = if needed 
}

// Key generate blocks 
resource "tls_private_key" "keypem" {
    algorithm = "RSA"
    rsa_bits = "4096"
  
}

resource "aws_key_pair" "keypair" {
    key_name = "ansible_key"
    public_key = tls_private_key.keypem.public_key_openssh
  }

resource "local_sensitive_file" "private_key" {
    filename = "${path.module}/ansible_key.pem"
    content = tls_private_key.keypem.private_key_pem
    file_permission = "0400"
  
}
// Setting the sercurity group for the instace
resource "aws_security_group" "ansiblesec" {
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]    
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port  = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
}

//creat ec2 instace   
data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"] 
}

resource "aws_instance" "ansible" {
    ami = data.aws_ami.ami.id 
    instance_type = "t3.micro"
    vpc_security_group_ids = [aws_security_group.ansiblesec.id]
    key_name = aws_key_pair.keypair.key_name


    provisioner "remote-exec" { 
        inline = [
            "sudo su",
            "sudo apt update -y",
            "sudo apt install -y  ansible",
            "ansible --version "
        ]
        connection {
            type = "ssh"
            user = "ubuntu"
            private_key = tls_private_key.keypem.private_key_pem
            host = self.public_ip
    
        }
    }
    provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --key-file ansible_key.pem -T 300 -i '${self.public_ip},', playbook.yaml"
}
     tags =  {
        name = "Ansible_server"
    }
} 

//print output 
output "ec2_public_ip" {
    value = aws_instance.ansible.public_ip
}  
