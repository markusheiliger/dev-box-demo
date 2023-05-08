
locals {

    image = {
      publisher = "MicrosoftWindowsDesktop"
      offer = "windows-ent-cpc"
      sku = "win11-22h2-ent-cpc-os"
      version = "latest"
    }

    prePackageScripts = [
    ]

    packages = [

		# {
		# 	name = ""
		# 	version = ""
		# 	source = ""
		# 	override = []
		# }

		{
			name = "Microsoft.VisualStudio.2022.Community"
			override = [
				# https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-community
				"--add", "Microsoft.VisualStudio.Workload.CoreEditor", 
				"--add", "Microsoft.VisualStudio.Workload.Azure", 
				"--add", "Microsoft.VisualStudio.Workload.Data",
				"--add", "Microsoft.VisualStudio.Workload.DataScience",
				"--add", "Microsoft.VisualStudio.Workload.ManagedDesktop", 
				"--add", "Microsoft.VisualStudio.Workload.Node", 
				"--add", "Microsoft.VisualStudio.Workload.Python",
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
			name = "Microsoft.VisualStudioCode"
			override = [
				"/VERYSILENT",
				"/NORESTART",
				"/MERGETASKS=desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath,!runcode"
			]
		},
		{
			name = "JetBrains.PyCharm.Community"
		},
		{
			name = "Microsoft.AzureDataStudio"
		}


    ]

    postPackageScripts = [
    ]

}
