packer {
  required_plugins {
    # https://github.com/rgl/packer-plugin-windows-update
    windows-update = {
      version = "0.14.1"
      source  = "github.com/rgl/windows-update"
    }
  }
}

source "azure-arm" "vm" {

  skip_create_image                   = false
  async_resourcegroup_delete          = true
  secure_boot_enabled                 = true
  vm_size                             = "Standard_D8d_v4" # default is Standard_A1

  # winrm options
  communicator                        = "winrm"
  winrm_username                      = "packer"
  winrm_insecure                      = true
  winrm_use_ssl                       = true
  os_type                             = "Windows"
  os_disk_size_gb                     = 1024
  
  # base image options (Azure Marketplace Images only)
  image_publisher                     = local.image.publisher
  image_offer                         = local.image.offer
  image_sku                           = local.image.sku
  image_version                       = local.image.version
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
  # Initialize VM 
  # =============================================================================================

  provisioner "powershell" {
    environment_vars = [
      "ADMIN_USERNAME=${build.User}",
      "ADMIN_PASSWORD=${build.Password}"
    ]
    script = "${path.root}/../_scripts/core/Prepare-VM.ps1"
  }

  provisioner "windows-restart" {
    # force restart to enable AutoLogon 
    restart_timeout = "30m"
  }

  # =============================================================================================
  # PRE Package Section 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = concat(
      ["${path.root}/../_scripts/core/NOOP.ps1"],
      local.prePackageScripts
    )
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
    script = "${path.root}/../_scripts/Install-WinGet.ps1"
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    inline = [templatefile("${path.root}/../_templates/InstallPackages.pkrtpl.hcl", { packages = local.packages })]
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # POST Package Section 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = concat(
      ["${path.root}/../_scripts/core/NOOP.ps1"],
      local.postPackageScripts
    )
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_timeout = "30m"
  }

  # =============================================================================================
  # PATCH Script Section 
  # =============================================================================================

  provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = setunion(
      ["${path.root}/../_scripts/core/NOOP.ps1"],
      fileset("${path.root}", "../_scripts/patch/*.ps1")
    ) 
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

  provisioner "windows-restart" {
    # force restart to enable AutoLogon 
    restart_timeout = "30m"
  }

  provisioner "powershell" {
	  elevated_user     = build.User
    elevated_password = build.Password
    timeout = "1h"
    script  = "${path.root}/../_scripts/core/Generalize-VM.ps1"
  }

  # =============================================================================================
  # On Error - Collect information from remote system
  # =============================================================================================

  error-cleanup-provisioner "powershell" {
    elevated_user     = build.User
    elevated_password = build.Password
    scripts = setunion(
      ["${path.root}/../_scripts/core/NOOP.ps1"],
      fileset("${path.root}", "../_scripts/error/*.ps1")
    ) 
  }
}
