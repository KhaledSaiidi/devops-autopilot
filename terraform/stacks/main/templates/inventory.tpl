[bastion]
bastion_host ansible_host=${bastion_public_ip} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ssh_private_key_path} ansible_python_interpreter=/usr/bin/python3
