function Get-IsAdmin() {
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Header() {

	param (
		[string] $Package,
		[string] $Version,
		[string] $Source,
		[string] $Arguments
	)

	if ([string]::IsNullOrEmpty($Version)) 		{ $Version = "latest" }
	if ([string]::IsNullOrEmpty($Source)) 		{ $Source = "winget" }
	if ([string]::IsNullOrEmpty($Arguments)) 	{ $Arguments = "none" }

@"
==========================================================================================================
WinGet Package Manager Install
----------------------------------------------------------------------------------------------------------
Package:   {0}
Version:   {1}
Source:    {2}
Arguments: {3}
----------------------------------------------------------------------------------------------------------
"@ -f ($Package, $Version, $Source, $Arguments) | Write-Host

}

function Write-Footer() {

	param (
		[string] $Package
	)

@"
----------------------------------------------------------------------------------------------------------
Finished installing {0} 
==========================================================================================================
"@ -f ($Package) | Write-Host

}

function Has-Property() {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object] $InputObject,
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    return ($null -ne ($InputObject | Select -ExpandProperty $Name -ErrorAction SilentlyContinue))
}

function Get-Property() {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object] $InputObject,
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [string] $DefaultValue = [string]::Empty
    )

    $value = ($InputObject | Select -ExpandProperty $Name -ErrorAction SilentlyContinue)

    if ($value) { 
        if ($value -is [array]) { $value = $value -join " " } 
    } else { 
        $value = $DefaultValue 
    }

	return $value
}

$packages = '${jsonencode(packages)}' | ConvertFrom-Json
$machinePackages = @()

Start-Process -FilePath "winget.exe" -ArgumentList ('source', 'reset', '--force') -NoNewWindow -Wait -ErrorAction SilentlyContinue
Start-Process -FilePath "winget.exe" -ArgumentList ('source', 'update', '--name', 'winget') -NoNewWindow -Wait -ErrorAction SilentlyContinue

$packages | ForEach-Object {

	Write-Header -Package $_.name -Version $_.version -Source $_.source -Arguments ($_.override -join " ").Trim()

	try
	{
		$package = $_
		$scope = ($_ | Get-Property -Name "scope" -DefaultValue "image")

		switch ($scope) {
			
			"image" {

				$arguments = ("install", ("--id {0}" -f $package.name),	"--exact")

				if ($_ | Has-Property -Name "version") { 	
					$arguments += "--version {0}" -f $package.version
				}
				
				$arguments += "--source {0}" -f ($package | Get-Property -Name "source" -DefaultValue "winget")

				if ($_ | Has-Property -Name "override") { 
					$arguments += "--override `"{0}`"" -f ($package | Get-Property -Name "override") 
				} else { 
					$arguments += "--silent" 
				} 

				$arguments += "--accept-package-agreements"
				$arguments += "--accept-source-agreements"
				$arguments += "--verbose-logs"

				$process = Start-Process -FilePath "winget.exe" -ArgumentList $arguments -NoNewWindow -Wait -PassThru
				
				if ($process.ExitCode -ne 0) { exit $process.ExitCode }
			}

			"machine" {
				
				Write-Host "Register package '$_' for ActiveSetup installation"
				$machinePackages += $package
			}

			default { 
				
				throw "The scope '$scope' is not supported"
			}
		}
	}
	finally
	{
		Write-Footer -Package $_.name 
	}

}

if ($machinePackages.count -gt 0 -and (Get-IsAdmin)) {

	$packerFolder = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles%\Packer")
	New-Item -Path $packerFolder -ItemType Directory -Force | Out-Null

	$packagesFile = Join-Path -Path $packerFolder -ChildPath "packages.json"
	$machinePackages | ConvertTo-Json | Out-File -FilePath $packagesFile
}