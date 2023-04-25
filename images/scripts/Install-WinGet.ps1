# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ProgressPreference = 'SilentlyContinue'	# hide any progress output

# Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
# Install-Script -Name winget-install -Force
# winget-install.ps1

function getLatestLink($match) {
	$uri = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
	$get = Invoke-RestMethod -uri $uri -Method Get -ErrorAction stop
	$data = $get[0].assets | Where-Object name -Match $match
	return $data.browser_download_url
}

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

Write-Host "[${env:username}] Downloading WinGet Packages ..."
$xamlPath = downloadFile -url "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.1" -name 'Microsoft.UI.Xaml.nuget.zip' -expand $true
$wingetPath = downloadFile -url (getLatestLink("msixbundle"))
$licensePath = downloadFile -url (getLatestLink("license1.xml"))

if ([Environment]::Is64BitOperatingSystem) {

	$vclibs = downloadFile -url "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"

	Write-Host "[${env:username}] Installing WinGet pre-requisites (64bit) ..."
	Add-AppxPackage -Path $vclibs -ErrorAction Stop
	Add-AppxPackage -Path (Join-Path -path $xamlPath -ChildPath 'tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx') -ErrorAction Stop

} else {

	$vclibs = downloadFile -url "https://aka.ms/Microsoft.VCLibs.x86.14.00.Desktop.appx"

	Write-Host "[${env:username}] Installing WinGet pre-requisites (32bit) ..."
	Add-AppxPackage -Path $vclibs -ErrorAction Stop
	Add-AppxPackage -Path (Join-Path -path $xamlPath -ChildPath 'tools\AppX\x86\Release\Microsoft.UI.Xaml.2.7.appx') -ErrorAction Stop
}

Write-Host "[${env:username}] Installing WinGet (user scope) ..."
Add-AppxPackage -Path $wingetPath -ErrorAction Stop

# Write-Host "[${env:username}] Installing WinGet (machine scope) ..."
# Add-AppxProvisionedPackage -online -PackagePath $wingetPath -LicensePath $licensePath -DependencyPackagePath $vclibs -ErrorAction Stop

# Write-Host "[${env:username}] Registering WinGet (user scope) ..."
# $wingetName = Get-AppxProvisionedPackage -Online | ? { $_.DisplayName -like 'Microsoft.DesktopAppInstaller' } | Select -ExpandProperty PackageName
# Add-AppxPackage -register "C:\Program Files\WindowsApps\$wingetName\appxmanifest.xml" -DisableDevelopmentMode

Write-Host "[${env:username}] Resetting WinGet Sources ..."
$process = Start-Process winget -ArgumentList "source reset --force --disable-interactivity" -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {

	Write-Host "[${env:username}] Adding WinGet Source Cache Package ..."
	Add-AppxPackage -Path "https://cdn.winget.microsoft.com/cache/source.msix" -ErrorAction Stop

	$settingsInfo = @(winget --info) | Where-Object { $_.StartsWith('User Settings:') } | Select-Object -First 1
	$settingsPath = $settingsInfo.Split(':') | Select-Object -Last 1 
	$settingsPath = [Environment]::ExpandEnvironmentVariables($settingsPath.Trim())

@"
{
	"`$schema": "https://aka.ms/winget-settings.schema.json",
	"installBehavior": {
		"preferences": {
			"scope": "machine"
		}
	}
}
"@ | Out-File $settingsPath -Encoding ASCII
}

exit $process.ExitCode