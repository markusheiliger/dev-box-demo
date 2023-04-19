# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ProgressPreference = 'SilentlyContinue'	# hide any progress output

Write-Host "[${env:username}] Enabling Virtual Machine Platform and Windows Subsystem for Linux ..."
Enable-WindowsOptionalFeature `
      -FeatureName "VirtualMachinePlatform", "Microsoft-Windows-Subsystem-Linux" `
	  -Online -All -NoRestart

