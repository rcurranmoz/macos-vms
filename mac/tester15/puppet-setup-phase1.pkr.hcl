packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

# Define a variable for VM name (allows dynamic selection)
variable "vm_name" {
  type    = string
  default = "sequoia-tester"
}

# Define a variable for the Vault file path
variable "vault_file" {
  type    = string
  default = "/Users/admin/Downloads/vault.yaml" # Default path
}

source "tart-cli" "puppet-setup-phase1" {
  vm_name   = "${var.vm_name}"  # Use dynamic variable
  cpu_count = 4
  memory_gb = 8
  disk_size_gb = 100
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "120s"
}

build {
  name    = "puppet-setup-phase1"
  sources = ["source.tart-cli.puppet-setup-phase1"]

  # Copy Vault file dynamically
  provisioner "file" {
    source      = "${var.vault_file}" # Uses the variable
    destination = "/tmp/vault.yaml"
  }

  provisioner "shell" {
    inline = [

      "echo 'Installing Rosetta 2...'",
      "echo admin | sudo -S softwareupdate --install-rosetta --agree-to-license",

      # Ensure vault.yaml is where run-puppet.sh expects it..
      "echo admin | sudo -S mkdir -p /var/root/",
      "echo admin | sudo -S cp /tmp/vault.yaml /var/root/vault.yaml",

      "echo 'Enabling passwordless sudo for admin...'",
      "echo admin | sudo -S sh -c 'mkdir -p /etc/sudoers.d/ && echo \"admin ALL=(ALL) NOPASSWD: ALL\" | tee /etc/sudoers.d/admin-nopasswd'",

      "echo 'Installing Command Line Tools...'",
      "touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress",
      "softwareupdate --list | sed -n 's/.*Label: \\(Command Line Tools for Xcode-.*\\)/\\1/p' | xargs -I {} softwareupdate --install '{}'",
      "rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress",

      "echo 'Downloading Puppet from S3...'",
      "curl -o /tmp/puppet-agent-7.28.0-1-installer.pkg https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/common/puppet-agent-7.28.0-1-installer.pkg",
      "echo 'Installing Puppet...'",
      "echo admin | sudo -S installer -pkg /tmp/puppet-agent-7.28.0-1-installer.pkg -target /",

      # Ensure the Puppet repo is cloned from the correct branch
      #"if [ ! -d /Users/admin/Desktop/puppet/ronin_puppet ]; then",
      #"  echo 'Cloning ronin_puppet repository...'",
      #"  git clone --branch master https://github.com/mozilla-platform-ops/ronin_puppet.git /Users/admin/Desktop/puppet/ronin_puppet",
      #"fi",

      # Ensure /etc/facter/facts.d exists
      #"echo admin | sudo -S mkdir -p /etc/facter/facts.d/",

      # Set Puppet role and ensure it's readable
      # "echo 'puppet_role=gecko_t_osx_1500_m_vms' | sudo tee /etc/facter/facts.d/puppet_role.txt > /dev/null",
      # "sudo chmod 644 /etc/facter/facts.d/puppet_role.txt",

      # Ensure /etc/puppet_role exists and matches Facter
      "echo 'gecko_t_osx_1500_m_vms' | sudo tee /etc/puppet_role > /dev/null",
      "sudo chmod 644 /etc/puppet_role",

      # Remove Facter cache to force reload
      #"echo admin | sudo -S rm -rf /opt/puppetlabs/facter/cache/",

      # Verify fact is correctly set
      #"echo 'Verifying puppet_role fact...'",
      #"sudo /opt/puppetlabs/bin/facter puppet_role",

      # Verify /etc/puppet_role exists before continuing
      #"if [ ! -f /etc/puppet_role ]; then",
      #"  echo 'ERROR: /etc/puppet_role was not created. Exiting...'",
      #"  exit 1",
      #"fi",

      # Small delay to ensure Facter fully loads the new fact
      #"sleep 3",

      "echo 'Downloading run-puppet.sh...'",
      "curl -o /tmp/run-puppet.sh https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/common/run-puppet.sh",
      "chmod +x /tmp/run-puppet.sh",

      "echo 'Pre-seeding Puppet repo....'",
      "sudo mkdir -p /opt/puppet_environments/mozilla-platform-ops",
      "sudo git clone --branch master https://github.com/mozilla-platform-ops/ronin_puppet.git /opt/puppet_environments/mozilla-platform-ops/ronin_puppet",

      "echo 'Applying temporary sed patches...'",
      "sudo sed -i '.bak' '/macos_tcc_perms/s/^/#/' /opt/puppet_environments/mozilla-platform-ops/ronin_puppet/modules/roles_profiles/manifests/roles/gecko_t_osx_1500_m_vms.pp",
      "sudo sed -i '.bak' '/safaridriver/s/^/#/' /opt/puppet_environments/mozilla-platform-ops/ronin_puppet/modules/roles_profiles/manifests/roles/gecko_t_osx_1500_m_vms.pp",
      "sudo sed -i '.bak' '/macos_directory_cleaner/s/^/#/' /opt/puppet_environments/mozilla-platform-ops/ronin_puppet/modules/roles_profiles/manifests/roles/gecko_t_osx_1500_m_vms.pp",
      "sudo sed -i '.bak' '/pipconf/s/^/#/' /opt/puppet_environments/mozilla-platform-ops/ronin_puppet/modules/roles_profiles/manifests/roles/gecko_t_osx_1500_m_vms.pp",

      "echo 'Running run-puppet.sh...'",
      "echo admin | sudo -S /tmp/run-puppet.sh",
    ]
  }
}