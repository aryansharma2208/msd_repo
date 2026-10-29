output "public_ip" {
  value = aws_instance.web.public_ip
}

output "service_url" {
  value = "http://${aws_instance.web.public_ip}/"
}

output "health_url" {
  value = "http://${aws_instance.web.public_ip}/health"
}

output "ssh_command" {
  value = "ssh ec2-user@${aws_instance.web.public_ip}"
}
