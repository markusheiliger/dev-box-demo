# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Write-Output '>>> Remove APPX packages ...'
Get-AppxPackage | % {
	Write-Output "- $($_.PackageFullName)"
	Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
}

Write-Output '>>> Waiting for GA Service (RdAgent) to start ...'
while ((Get-Service RdAgent -ErrorAction SilentlyContinue) -and ((Get-Service RdAgent).Status -ne 'Running')) { Start-Sleep -s 5 }

Write-Output '>>> Waiting for GA Service (WindowsAzureTelemetryService) to start ...'
while ((Get-Service WindowsAzureTelemetryService -ErrorAction SilentlyContinue) -and ((Get-Service WindowsAzureTelemetryService).Status -ne 'Running')) { Start-Sleep -s 5 }

Write-Output '>>> Waiting for GA Service (WindowsAzureGuestAgent) to start ...'
while ((Get-Service WindowsAzureGuestAgent -ErrorAction SilentlyContinue) -and ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running')) { Start-Sleep -s 5 }

Write-Output '>>> Sysprepping VM ...'
Remove-Item $Env:SystemRoot\system32\Sysprep\unattend.xml -Force -ErrorAction SilentlyContinue

# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep-command-line-options?view=windows-11
$proc = Start-Process -Filepath $Env:SystemRoot\System32\Sysprep\Sysprep.exe -ArgumentList "/generalize /oobe /mode:vm /quiet /quit" -NoNewWindow -PassThru
$procTimeout = (Get-Date).AddMinutes(15) # the number of minutes we give sysprep to finish the job

while($true) { 
	
	$imageState = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State | Select ImageState

	if ((Get-Date) -gt $procTimeout) {

		Write-Output "TIMEOUT !!!"
		if (!$proc.hasExited) { $proc.Kill(); throw "SysPrep ran into timeout." }

	} elseif ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { 

		Write-Output $imageState.ImageState
		Start-Sleep -s 10  

	} else { 

		Write-Output $imageState.ImageState
		break

	} 
}
