
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
		#  	scope = "[image|machine]" 	< DFAULT: image
		# 	version = ""				< DFAULT: latest
		# 	source = ""					< DFAULT: winget
		# 	override = []
		# }

		{
			name = "Microsoft.PowerShell"
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
			override = [
				"install",
				"--quiet",
				"--accept-license"
			]
		},

		{
			name = "Microsoft.AzureCLI"
		},

		{
			name = "Postman.Postman"
			scope = "machine"
		},
		{
			name ="Google.Chrome"
		},
		{
			name = "Mozilla.Firefox"
		}
    ]

    postPackageScripts = [
    ]

}
