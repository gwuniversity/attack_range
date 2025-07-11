# -----------------------------------------------------------------------------
# Windows Server Instance Configuration
# -----------------------------------------------------------------------------
# This resource block configures a Windows Server instance in Google Cloud Platform.
# The instance includes disk, network, metadata settings, and remote provisioning
# to set up essential configurations for attack-range simulations.
# -----------------------------------------------------------------------------

# Search for the latest Windows Server image
data "google_compute_image" "windows_server" {
  count   = length(var.windows_servers)
  family  = var.windows_servers[count.index].image
  project = "windows-cloud"
}

# Windows Server Instance Configuration
resource "google_compute_instance" "windows_server" {
  count        = length(var.windows_servers)
  name         = "${var.general.attack_range_name}-windows-server-${var.general.key_name}-${count.index}"
  machine_type = "n2-standard-4"
  zone         = var.gcp.zone

  # Boot Disk Configuration
  boot_disk {
    initialize_params {
      image = data.google_compute_image.windows_server[count.index].self_link      # Windows Server image ID
      size  = 50  # Disk size in GB
      type  = "pd-ssd"  # Disk type, e.g., "pd-ssd"
    }
    auto_delete = true
  }

  # Network Interface Configuration
  network_interface {
    network    = var.vpc_network
    subnetwork = var.subnetwork
    network_ip = "10.0.1.${14 + count.index}"
    access_config {                            # Assigns an external NAT IP if available
      nat_ip = length(google_compute_address.windows_ip) > count.index ? google_compute_address.windows_ip[count.index].address : null
    }
  }

  # Assign the Windows Service Account to this instance
    # service_account {
    #     email  = var.windows_sa_email
    #     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }

  # Metadata for Windows Startup Script
  # This script configures WinRM, firewall rules, and enables the Administrator account.
  metadata = {
    windows-startup-script-ps1 = <<-EOF
        $admin = [adsi]("WinNT://./Administrator, user")
        $admin.PSBase.Invoke("SetPassword", "${var.general.attack_range_password}")
        if ($?) {
            Add-Content -Path C:\startup_log.txt -Value "Password set successfully for Administrator."
        } else {
            Add-Content -Path C:\startup_log.txt -Value "Failed to set password for Administrator."
        }
        net user Administrator /active:yes
        if ($admin.AccountDisabled -eq $false) {
            Add-Content -Path C:\startup_log.txt -Value "Administrator account enabled."
        } else {
            Add-Content -Path C:\startup_log.txt -Value "Administrator account NOT enabled."
        }
        winrm quickconfig -q

        # Enable Debugging mode
        # winrm set winrm/config/service @{EnableDebugLogging="true"}

        # Increase Max Concurrent Requests
        winrm set winrm/config/service '@{MaxConcurrentUsers="50"}'

        # Increase Max Connections per Shell
        winrm set winrm/config/winrs '@{MaxShellsPerUser="50"}'

        # Increase Memory Limit per Shell
        # winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="4096"}'

        # Set operation timeout to 10 minutes
        winrm set winrm/config '@{MaxTimeoutms="3600000"}'
        # winrm set winrm/config/winrs '@{IdleTimeout="600000"}'

        # Increase the request queue limit
        # winrm set winrm/config/winrs '@{MaxProcessesPerShell="25"}'

        # Increase Max Concurrent Operations for WinRS
        # winrm set winrm/config/service '@{MaxConcurrentOperations="4294967295"}'
        # winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser="4294967295"}'
        winrm set winrm/config/service '@{MaxConcurrentOperations="4294967295"; MaxConcurrentOperationsPerUser="4294967295"; MaxConnections="4294967295"}'
        winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="4096"; MaxProcessesPerShell="50"; IdleTimeout="3600000"}'

        winrm set winrm/config/service '@{AllowUnencrypted="true"}' 

        Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value true

        # Add the Ansible controller to trusted hosts
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

        # Enable KeepAlive for the HTTPS Listener
        if (Test-Path WSMan:\localhost\Service\KeepAlive) {
            Write-Host "Keep alive true"
            Set-Item -Path WSMan:\localhost\Service\KeepAlive -Value $true
        } else {
            Write-Host "KeepAlive path does not exist."
        }

        winrm set winrm/config/service/auth '@{Basic="true"}'
        $ExternalIP = Invoke-RestMethod -Uri "http://ifconfig.me/ip"
        # $ExternalIP = (Invoke-WebRequest -uri http://metadata.google.internal/computeMetadata/v1/instances/external_ip -Headers @{"Metadata-Flavor"="Google"}) | Select-Object -ExpandProperty Content # Get external IP
        $InternalIP = (Get-NetIPAddress | Where-Object {$_.InterfaceAlias -like "*Ethernet*" -and $_.AddressFamily -eq 'IPv4'}).IPAddress  # Get internal IP

        # Use internal IP or hostname for the certificate
        $hostname = [System.Net.Dns]::GetHostName()
        # $Cert = New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation "Cert:\LocalMachine\My"
        $Cert = New-SelfSignedCertificate -DnsName $hostname, $ExternalIP, $InternalIP -CertStoreLocation "Cert:\LocalMachine\My"  # Use external and internal IPs
        $CertDetails = @{
          Thumbprint = $Cert.Thumbprint
          Subject = $Cert.Subject
          DnsNameList = $Cert.DnsNameList
        }
        $CertDetails | Out-File -FilePath C:\certificate_details.txt
        $Thumbprint = $Cert.Thumbprint

        # Check and create HTTP listener on port 5985
        $existingHttpListener = (winrm enumerate winrm/config/Listener | Select-String -Pattern "Transport=HTTP")
        if (-not $existingHttpListener) {
            winrm create winrm/config/Listener?Address=*+Transport=HTTP+Port=5985
            Write-Host "HTTP listener created on port 5985."
        } else {
            Write-Host "HTTP listener already exists on port 5985."
        }

        # Check and create HTTPS listener on port 5986
        $existingHttpsListener = (winrm enumerate winrm/config/Listener | Select-String -Pattern "Transport=HTTPS")
        if (-not $existingHttpsListener) {
            winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname="$hostname"; CertificateThumbprint="$Thumbprint"}
            Write-Host "HTTPS listener created on port 5986."
        } else {
            Write-Host "HTTPS listener already exists on port 5986."
        }

        netsh advfirewall firewall add rule name="WinRM HTTP" protocol=TCP dir=in localport=5985 action=allow
        netsh advfirewall firewall add rule name="WinRM HTTPS" protocol=TCP dir=in localport=5986 action=allow

        # Add firewall rule for RDP (port 3389)
        netsh advfirewall firewall add rule name="RDP" protocol=TCP dir=in localport=3389 action=allow

        net stop winrm
        sc.exe config winrm start=auto

        # Set WinRM to restart automatically on failure
        sc.exe failure winrm reset= 0 actions= restart/5000/restart/5000/restart/5000

        # Define task name
        $taskName = "Restart WinRM Service"

        # Check if the task already exists
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            # Remove the existing task
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "Existing task '$taskName' removed."
        }

        # Define the action and trigger
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-Command "Restart-Service winrm"'
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365) # 1 year

        # Register the new task
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Restarts WinRM if it crashes"

        Write-Host "Task '$taskName' created or recreated successfully."
        Get-ScheduledTask | Where-Object { $_.TaskName -eq "Restart WinRM Service" }

        net start winrm
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
        Enable-PSRemoting -SkipNetworkProfileCheck -Force

        # Get the system drive dynamically
        # $drive_letter = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }).Name[0]
        # Get the drive letter of the first drive with free space
        $drive_letter = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }).Name[0]

        # Get the partition size details
        try {
            # Get the drive letter of the first drive with free space
            $drive_letter = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }).Name[0]

            # Get the partition size details
            $size = Get-PartitionSupportedSize -DriveLetter $drive_letter
            Write-Host "Size Left: Min = $($size.SizeMin), Max = $($size.SizeMax)"

            # Check if the maximum available size is greater than or equal to 1GB
            if ($size.SizeMax -ge (1GB)) {
                # Ensure the new size is valid and larger than the current partition size
                $currentPartitionSize = (Get-Partition -DriveLetter $drive_letter).Size
                Write-Host "Current Partition Size: $currentPartitionSize bytes"

                if ($size.SizeMax -gt $currentPartitionSize) {
                    try {
                        # Resize the partition to the maximum supported size
                        Resize-Partition -DriveLetter $drive_letter -Size $size.SizeMax
                        Write-Host "Partition resized to $($size.SizeMax) bytes."
                    } catch {
                        Write-Host "Error resizing partition: $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "No resize needed. Maximum size is equal to or less than the current partition size."
                }
            } else {
                Write-Host "Insufficient space to resize the partition. Maximum available is $($size.SizeMax) bytes. Minimum required is 1GB."
            }
        } catch {
            Write-Host "Error during partition resize operation: $($_.Exception.Message)"
        }
        winrm enumerate winrm/config/Listener | Out-File -FilePath C:\winrm_listener_status.txt
    EOF
  }

  # Tags and Labels for Instance Identification
  tags = ["gcp-infrastructure", "windows-server", "attack-range"]
  labels = {
    name = "ar-win-${var.general.key_name}-${var.general.attack_range_name}-${count.index}"
  }

  # Provisioners for Initial Setup
  # Remote Exec - Verifies instance setup over WinRM
  provisioner "remote-exec" {
    inline = ["echo booted"]
    connection {
      type     = "winrm"
      user     = "Administrator"
      password = var.general.attack_range_password
      host     = self.network_interface[0].access_config[0].nat_ip
      port     = 5986
      insecure = true
      https    = true
      timeout  = "90m"
    }
  }

  # Local Exec - Generates Ansible variables and runs playbook
  provisioner "local-exec" {
    working_dir = "../ansible"
    command = <<-EOT
      cat > vars/windows_vars_${count.index}.json << 'EOF'
      {
        "ansible_user": "Administrator",
        "ansible_password": "${var.general.attack_range_password}",
        "attack_range_password": "${var.general.attack_range_password}",
        "general": ${jsonencode(var.general)},
        "splunk_server": ${jsonencode(var.splunk_server)},
        "simulation": ${jsonencode(var.simulation)},
        "windows_servers": ${jsonencode(var.windows_servers[count.index])},
        "caldera_server": ${jsonencode(var.caldera_server)},
      }
      EOF
    EOT
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${self.network_interface[0].access_config[0].nat_ip},' windows.yml -e @vars/windows_vars_${count.index}.json"
  }
}

# -----------------------------------------------------------------------------
# Static IP Configuration for Windows Server
# -----------------------------------------------------------------------------
# Allocates a static external IP for each Windows instance if elastic IPs are enabled.
# -----------------------------------------------------------------------------
resource "google_compute_address" "windows_ip" {
  count  = (var.gcp.use_static_ip == "1") ? length(var.windows_servers) : 0
  name   = "windows-ip-${var.general.key_name}-${var.general.attack_range_name}-${count.index}"
  region = var.gcp.region
}
