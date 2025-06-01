variable "docker_image" {}
variable "docker_tag" {}
variable "instance_type" {
  default = "t2.micro"
}
variable "key_name" {}
variable "desired_capacity" {
  default = 2
}
variable "vpc_id" {}
variable "public_subnets" {
  type = list(string)
}
