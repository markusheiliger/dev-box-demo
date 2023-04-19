# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ProgressPreference = 'SilentlyContinue'	# hide any progress output

function downloadFile() {
	param(
		[Parameter(Mandatory=$true)][string] $url,
		[Parameter(Mandatory=$false)][string] $name,
		[Parameter(Mandatory=$false)][boolean] $expand		
	)

	$path = Join-Path -path $env:temp -ChildPath (Split-Path $url -leaf)
	if ($name) { $path = Join-Path -path $env:temp -ChildPath $name }
	
	Write-Host "$url >> $path"
	Invoke-WebRequest -Uri $url -OutFile $path
	
	if ($expand) {
		$arch = Join-Path -path $env:temp -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($name))
		Expand-Archive -Path $path -DestinationPath $arch -Force
		return $arch
	}
	
	return $path
}

$localDockerUsersMembers = Get-LocalGroupMember -Group "docker-users" -ErrorAction SilentlyContinue
if ($localDockerUsersMembers) {

	if (-not ($localDockerUsersMembers -like "NT AUTHORITY\Authenticated Users")) {
		Write-Host "[${env:username}] Adding 'Authenticated Users' to docker-users group ..."
		Add-LocalGroupMember -Group "docker-users"  -Member "NT AUTHORITY\Authenticated Users"
	}

	Write-Host "[${env:username}] Downloading WSL2 update ..."
	$installer = downloadFile -url "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"

	Write-Host "[${env:username}] Installing WSL2 update ..."
	$process = Start-Process msiexec.exe -ArgumentList "/I $installer /quiet" -NoNewWindow -Wait -PassThru

	if ($process.ExitCode -eq 0) {
		Write-Host "[${env:username}] Setting default WSL version to 2 ..."
		$process = Start-Process wsl -ArgumentList "--set-default-version 2" -NoNewWindow -Wait -PassThru
	}

	exit $process.ExitCode
}
