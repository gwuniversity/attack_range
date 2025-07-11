# Set Location
if(!$PSScriptRoot) {
    $Global:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}
Set-Location -Path $PSScriptRoot

# Force tls
if ([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13'){
	[Net.ServicePointManager]::SecurityProtocol = "Tls13, Tls12"
} else {
	[Net.ServicePointManager]::SecurityProtocol = "Tls12"
}

# We'll do the error handling, k?
$ErrorActionPreference = "Stop"

# Set OS Variables, if needed
if ( (Get-Variable -Name "IsWindows" -ErrorAction SilentlyContinue).Count -eq 0 )
{
    # We know we're on Windows PowerShell 5.1 or earlier
    $Script:IsWindows = $true
    $Script:IsLinux = $Script:IsMacOS = $false
}

# Supported PowerShell versions
# MacOS and Linux supported by PowerShell Core 6.0 and 7
# Windows is supported by PowerShell 3.0+
# PowerShell 2.0 is missing at least these functions: Get-TimeZone, Set-TimeZone, Get-CimInstance, ConvertTo-Json
if ($PSVersionTable.PSVersion.Major -lt 3) 
{
    Write-Host -ForegroundColor Yellow "[!] Error: this script requires PowerShell 3.0 or greater"
    throw "PowerShell Version Too Old"
}

# Check if we're elevated
if ($IsWindows)
{
    # Verify that the script is being run as an administrator
    if ( -not (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) )
    {
        Write-Host -ForegroundColor Yellow "[!] Error: this script needs to be run as an administrator"
        throw "Insufficient Privileges"
    }
} 
else
{

    # Verify that the script is being run as root
    if ( (id -u) -ne 0 )
    {
        Write-Host -ForegroundColor Yellow "[!] Error: this script needs to be run as root"
        throw "Insufficient Privileges"
    }

    # Verify that they used sudo, and we can use sudo again to drop privs
    if ( -not (sh -c set | grep SUDO_USER) )
    {
        Write-Host -ForegroundColor Yellow "[*] No SUDO_USER found; please elevate with sudo"
        throw "Error dropping privileges"
    }
    else {
        $script:sudoer = $env:SUDO_USER
    }

}
if (-not [Environment]::Is64BitOperatingSystem){
    Write-Host -ForegroundColor Yellow "[!] Running in x86 is not currently supported."
    throw "Unsupported architecture"
}
# Import all modules from the capattack folder
Get-ChildItem $PSScriptRoot |
    Where-Object {$_.PSIsContainer -and ($_.Name -eq 'modules')} |
    ForEach-Object {Get-ChildItem "$($_.FullName)\*" -Include '*.ps1'} |
    ForEach-Object {. $_.FullName}

Write-Host -ForegroundColor Green "[*] CapAttack imported successfully!"
Write-Host "[*] Use 'Start-Capattack' to start a new session and 'Stop-Capattack' when you're done"
Write-Host "[*] Use 'CapAttack-Status' to see if an existing session is recording or not"
Write-Host "[*] Use 'Install-Capattack' to pre-install dependencies"