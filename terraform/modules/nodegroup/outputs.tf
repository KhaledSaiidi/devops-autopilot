output "bastion_public_ip" {
  value       = try(aws_instance.bastion[0].public_ip, null)
  description = "Public IP of the bastion host (if enabled)."
}

output "bastion_security_group_id" {
  value       = try(aws_security_group.bastion_sg[0].id, null)
  description = "Security group ID for the bastion host (if enabled)."
}

output "ssh_key_name" {
  value       = local.effective_ssh_key_name
  description = "AWS key pair name in use for bastion and nodes."
}

output "ssh_private_key_path" {
  description = "Local path to the generated private key (if create_ssh_key=true)."
  value       = var.create_ssh_key ? abspath(local_file.private_key[0].filename) : null
}

output "worker_security_group_id" {
  description = "Security group ID used by worker nodes."
  value       = aws_security_group.worker_sg.id
}
