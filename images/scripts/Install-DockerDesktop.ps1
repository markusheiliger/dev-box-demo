# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ProgressPreference = 'SilentlyContinue'	# hide any progress output

$installerName = "Docker Desktop Installer.exe"
$installerPath = Join-Path -Path $env:TEMP -ChildPath $installerName

Write-Host "[${env:username}] Downloading Docker Desktop ..."
(new-object net.webclient).DownloadFile('https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe', $installerPath) 			# lates version
# (new-object net.webclient).DownloadFile('https://desktop.docker.com/win/main/amd64/99724/Docker%20Desktop%20Installer.exe', $installerPath)	# version 4.17.0


Write-Host "[${env:username}] Installing Docker Desktop ..."
$process = Start-Process $installerPath -ArgumentList `
	"install", `
	"--quiet", `
	"--accept-license" `
	-NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {

	$localDockerUsersMembers = Get-LocalGroupMember -Group "docker-users" -ErrorAction SilentlyContinue
	if ($localDockerUsersMembers -and -not ($localDockerUsersMembers -like "NT AUTHORITY\Authenticated Users")) {
		Write-Host "[${env:username}] Adding 'Authenticated Users' to docker-users group ..."
		Add-LocalGroupMember -Group "docker-users"  -Member "NT AUTHORITY\Authenticated Users"
	}
}

exit $process.ExitCode
