
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
			name = "Microsoft.VisualStudioCode"
			override = [
				"/VERYSILENT",
				"/NORESTART",
				"/MERGETASKS=desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath,!runcode"
			]
		},
		{
			name = "Microsoft.VisualStudio.2022.Enterprise"
			override = [
				# https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-enterprise
				"--add", "Microsoft.VisualStudio.Workload.CoreEditor", 
				"--add", "Microsoft.VisualStudio.Workload.NetCrossPlat",
				"--includeRecommended",
				"--includeOptional",
				"--installWhileDownloading",
				"--quiet",
				"--norestart",
				"--force",
				"--wait",
				"--nocache"
			]
		},
		{
			name = "Google.AndroidStudio"
		},
		{
			name = "Wondershare.MirrorGo"
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
			name = "Microsoft.Bicep"
		},
		{
			name = "Microsoft.AzureCLI"
		},
		{
			name = "Microsoft.Azure.StorageExplorer"
		},

		{
			name = "Google.Chrome"
		},
		{
			name = "Mozilla.Firefox"
		}
    ]

    postPackageScripts = [
		"${path.root}/../_scripts/Install-FabulaTechUSBServer.ps1"
    ]

}
