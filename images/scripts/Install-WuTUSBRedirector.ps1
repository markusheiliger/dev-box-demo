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

$7zip = [System.Environment]::ExpandEnvironmentVariables("%programfiles%\7-Zip\7z.exe")

Write-Host "[${env:username}] Downloading WuT USB Redirector ..."
$archive = downloadFile -url "https://www.wut.de/windows-usb-umlenkung" -name "USBRedirector.zip"
$extract = Join-Path (Split-Path -Path $archive) -ChildPath ([io.path]::GetFileNameWithoutExtension($archive))

if (-not(Test-Path $7zip -PathType Leaf)) {
	Write-Host "[${env:username}] Installing 7zip ..."
	$process = Start-Process winget -ArgumentList 'install 7zip.7zip --source winget --silent --accept-package-agreements --accept-source-agreements --verbose-logs' -NoNewWindow -Wait -PassThru
	if ($process.ExitCode -ne 0) { exit $process.ExitCode }
}

Write-Host "[${env:username}] Extracting archive ..."
$process = Start-Process $7zip -ArgumentList "x $archive -o$extract" -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) { exit $process.ExitCode }

Write-Host "[${env:username}] Extracting installer ..."
$source = Get-ChildItem -Path $extract -Filter '302' -Recurse | Select-Object -Last 1 -ExpandProperty Fullname
$installer = [System.IO.Path]::ChangeExtension($archive, ".msi")
Copy-Item $source -Destination $installer -Force -Verbose

Write-Host "[${env:username}] Installing USB redirector ..."
$process = Start-Process msiexec.exe -ArgumentList "/I $installer /qn" -NoNewWindow -Wait -PassThru
exit $process.ExitCode
