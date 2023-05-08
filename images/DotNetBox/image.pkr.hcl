
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
			name = "Microsoft.DotNet.SDK.3_1"
		},
		{
			name = "Microsoft.DotNet.SDK.5"
		},
		{
			name = "Microsoft.DotNet.SDK.6"
		},
		{
			name = "Microsoft.DotNet.SDK.7"
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
				"--add", "Microsoft.VisualStudio.Workload.Azure", 
				"--add", "Microsoft.VisualStudio.Workload.NetCrossPlat",
				"--add", "Microsoft.VisualStudio.Workload.NetWeb",
				"--add", "Microsoft.VisualStudio.Workload.Node", 
				"--add", "Microsoft.VisualStudio.Workload.Python",
				"--add", "Microsoft.VisualStudio.Workload.ManagedDesktop", 
				"--includeRecommended",
				"--installWhileDownloading",
				"--quiet",
				"--norestart",
				"--force",
				"--wait",
				"--nocache"
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
			name = "Microsoft.SQLServerManagementStudio"
		},
		{
			name = "Docker.DockerDesktop"
		},
		{
			name = "VideoLAN.VLC"
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
			name = "Microsoft.AzureDataStudio"
		},

		{
			name ="Google.Chrome"
		},
		{
			name = "Mozilla.Firefox"
		}
    ]

    postPackageScripts = [
		"${path.root}/../_scripts/Install-WuTCOMRedirector.ps1",
		"${path.root}/../_scripts/Install-WuTUSBRedirector.ps1",
		"${path.root}/../_scripts/Install-FabulaTechUSBServer.ps1",
		"${path.root}/../_scripts/Install-RadzioModbusMasterSimulator.ps1"
    ]

}
