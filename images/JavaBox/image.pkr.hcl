
locals {

    image = {
      publisher = "MicrosoftWindowsDesktop"
      offer = "windows-ent-cpc"
      sku = "win11-22h2-ent-cpc-os"
      version = "latest"
    }

    prePackageScripts = [
	    "${path.root}/../_scripts/Install-WSL2.ps1"
    ]

    packages = [

		# {
		# 	name = ""
		# 	version = ""
		# 	source = ""
		# 	override = []
		# }

		{
			name = "Microsoft.PowerShell"
		},

		{
			name = "Microsoft.OpenJDK.17"
		},

		{
			name = "Microsoft.VisualStudioCode"
			override = [
				"/VERYSILENT",
				"/NORESTART",
				"/MERGETASKS=desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath,!runcode"
			]
		},
		{
			name = "JetBrains.IntelliJIDEA.Community"
		},

		{
			name = "Git.Git"
			override = [
				"/VERYSILENT",
				"/SUPPRESSMSGBOXES",
				"/NORESTART",
				"/NOCANCEL",
				"/SP-",
				"/WindowsTerminal",
				"/WindowsTerminalProfile",
				"/DefaultBranchName:main",
				"/Editor:VisualStudioCode"
			]
		},
		{
			name = "GitHub.cli"
		},
		{
			name = "GitHub.GitHubDesktop"
		},
		
		{
			name = "Docker.DockerDesktop"
		},

		{
			name = "cURL.cURL"
		},
		{
			name = "Postman.Postman"
		},

		{
			name = "Microsoft.Bicep"
		},
		{
			name = "Microsoft.AzureCLI"
		},

		{
			name = "Google.Chrome"
		},
		{
			name = "Mozilla.Firefox"
		}
    ]

    postPackageScripts = [
		"${path.root}/../_scripts/Install-WuTCOMRedirector.ps1",
		"${path.root}/../_scripts/Install-WuTUSBRedirector.ps1",
		"${path.root}/../_scripts/Install-FabulaTechUSBServer.ps1"
    ]

}
