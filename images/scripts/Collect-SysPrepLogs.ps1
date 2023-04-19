# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ErrorActionPreference = "SilentlyContinue"

$logFiles = @(
	"$Env:SystemRoot\System32\Sysprep\Panther\setupact.log",
	"$Env:SystemRoot\System32\Sysprep\Panther\setuperr.log",

	"$Env:SystemRoot\System32\Sysprep\setupact.log",
	"$Env:SystemRoot\System32\Sysprep\setuperr.log",

	"$Env:SystemRoot\Panther\UnattendGC\setupact.log",
	"$Env:SystemRoot\Panther\UnattendGC\setuperr.log",

	"$Env:SystemRoot\Panther\setupact.log",
	"$Env:SystemRoot\Panther\setuperr.log"
)

$logFiles | ? { Test-Path $_ } | % {

	Write-Output "=========================================================================================================="
	Write-Output " SysPrep Log: $_"
	Write-Output "=========================================================================================================="
	Get-Content -Raw -Path $_
	Write-Output "=========================================================================================================="
}
