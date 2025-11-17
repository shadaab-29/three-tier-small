variable "region" {
  default = "ap-south-1"
}

variable "project" {
  default = "smallproj"
}

variable "ami" {
  description = "AMI ID for Ubuntu"
}

variable "my_ip" {
  description = "Your IP with CIDR (e.g. 49.37.xx.xx/32)"
}

variable "public_key_path" {
  description = "Path to your SSH public key"
}
