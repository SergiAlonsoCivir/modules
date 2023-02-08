output "public_ip" {
  value = aws_lb.sergi-server.dns_name
  description = "THe public IP address of the web server"
}

output "sg_id" {
  value = aws_security_group.sg-lb-sergi.id
}