# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ErrorActionPreference = "SilentlyContinue"

If ([string]::IsNullOrEmpty($Env:ADMIN_USERNAME)) { Throw "Env:ADMIN_USERNAME must be set" }
If ([string]::IsNullOrEmpty($Env:ADMIN_PASSWORD)) { Throw "Env:ADMIN_PASSWORD must be set" }

Write-Host ">>> Enable AutoLogon for elevated task processing ..."
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value 1 -type String
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultUsername -Value "$Env:ADMIN_USERNAME" -type String
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultPassword -Value "$Env:ADMIN_PASSWORD" -type String

Write-Host ">>> Disable User Access Control ..."
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -Value 0 -type DWord

Write-Host ">>> Remove existing SysPrep logs ..."
Remove-Item -Path $env:SystemRoot\Panther -Recurse -Force | Out-Null
Remove-Item -Path $env:SystemRoot\System32\Sysprep\Panther -Recurse -Force | Out-Null
Remove-Item -Path $Env:SystemRoot\System32\Sysprep\unattend.xml -Force | Out-Null

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Winget-AutoUpdate" 
$regKey = Get-Item $regPath -ErrorAction SilentlyContinue

if ($regKey) {
	Write-Host ">>> Disable WinGet AutoUpdate ..."
	New-ItemProperty $regPath -Name WAU_DisableAutoUpdate -Value 1 -Force | Out-Null
}