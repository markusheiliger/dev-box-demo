packer {
  required_plugins {
    # https://github.com/rgl/packer-plugin-windows-update
    windows-update = {
      version = "0.14.1"
      source  = "github.com/rgl/windows-update"
    }
  }
}

# https://www.packer.io/plugins/builders/azure/arm
source "azure-arm" "vm" {
  skip_create_image                   = false
  async_resourcegroup_delete          = true
  vm_size                             = "Standard_D8d_v4" # default is Standard_A1
  # winrm options
  communicator                        = "winrm"
  winrm_username                      = "packer"
  winrm_insecure                      = true
  winrm_use_ssl                       = true
  os_type                             = "Windows"
  # base image options (Azure Marketplace Images only)
  image_publisher                     = "MicrosoftWindowsDesktop"             # "MicrosoftVisualStudio"
  image_offer                         = "windows-ent-cpc"                     # "visualstudioplustools"
  image_sku                           = "win11-22h2-ent-cpc-os"               # "vs-2022-ent-general-win11-m365-gen2"
  image_version                       = "latest"
  use_azure_cli_auth                  = true
  # packer creates a temporary resource group
  subscription_id                     = var.gallerySubscription
  location                            = var.galleryLocation
  temp_resource_group_name            = "PKR-${var.imageName}-${var.imageVersion}"
  shared_image_gallery_destination {
    subscription                      = var.gallerySubscription
    gallery_name                      = var.galleryName
    resource_group                    = var.galleryResourceGroup
    image_name                        = var.imageName
    image_version                     = var.imageVersion
    replication_regions               = [ var.galleryLocation ]
    storage_account_type              = "Premium_LRS" # default is Standard_LRS
  }
}

build {

  sources = ["source.azure-arm.vm"]

  # =============================================================================================
  # Initialize VM - Enable software installation with elevated privilidges
  # =============================================================================================
  
  provisioner "powershell" {
    environment_vars = [
      "ADMIN_USERNAME=${build.User}",
      "ADMIN_PASSWORD=${build.Password}"
    ]
    script = "${path.root}/../scripts/Enable-AutoLogon.ps1"
  }

  provisioner "windows-restart" {
    # force restart to enable AutoLogon 
    restart_timeout = "30m"
  }

  # =============================================================================================
  # Core Services and Tools 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = [
      "${path.root}/../scripts/Install-Chocolatey.ps1",
      "${path.root}/../scripts/Install-WinGet.ps1",
      "${path.root}/../scripts/Install-WSL2.ps1"
    ]
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # Chocolatey Packages 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    inline = [
      "@() | % `",
      "{ choco install $_ --yes --no-progress }"
    ]
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # WinGet Packages 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    inline = [
      "@( 'Google.Chrome', 'Mozilla.Firefox', 'Microsoft.SQLServerManagementStudio', 'Docker.DockerDesktop' ) `",
      "| % { winget install $_ --source winget --silent --accept-package-agreements --accept-source-agreements --verbose-logs }",
      "winget export -o c:\\winget.json --include-versions --accept-source-agreements --disable-interactivity"
    ]
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # Patch Packages 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = [
      "${path.root}/../scripts/Patch-DockerDesktop.ps1",
    ]
  }
  
  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # Custom Packages 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = [
      "${path.root}/../scripts/Install-WuTCOMRedirector.ps1",
      "${path.root}/../scripts/Install-WuTUSBRedirector.ps1"
    ]
  }
  
  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # Finalize Image - Install Windows Updates and Generalize VM 
  # =============================================================================================

  provisioner "windows-update" {
    # https://github.com/rgl/packer-plugin-windows-update
  }

  provisioner "powershell" {
	  elevated_user     = build.User
    elevated_password = build.Password
    scripts = [
      "${path.root}/../scripts/Disable-AutoLogon.ps1",
      "${path.root}/../scripts/Generalize-VM.ps1"
    ]
  }

  # =============================================================================================
  # On Error - Collect information from remote system
  # =============================================================================================

  error-cleanup-provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = [
      "${path.root}/../scripts/Collect-WinGetLogs.ps1",
      "${path.root}/../scripts/Collect-SysPrepLogs.ps1",
    ]
  }
}
