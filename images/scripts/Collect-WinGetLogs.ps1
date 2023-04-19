# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ErrorActionPreference = "SilentlyContinue"

$diagnosticInfo = @(winget --info) | Where-Object { $_.StartsWith('Logs:') } | Select-Object -First 1
$diagnosticPath = $diagnosticInfo.Split(':') | Select-Object -Last 1 
$diagnosticPath = [Environment]::ExpandEnvironmentVariables($diagnosticPath.Trim())

Get-ChildItem -Path $diagnosticPath -Filter *.log -File | Sort-Object LastWriteTime | % {

	Write-Output "=========================================================================================================="
	Write-Output " WinGet Log: $_"
	Write-Output "=========================================================================================================="
	Get-Content -Raw -Path $_
	Write-Output "=========================================================================================================="
}
