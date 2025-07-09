function Install-Capattack
{
    Param (
        
        [Parameter(Mandatory=$false)]
        [string]
        $choice,
        
        [Parameter(Mandatory=$false)]
        [Switch]
        $Shortcuts
    )
    Push-Location
    try {
        Set-Location (Split-Path (Get-Module capattack).Path -Parent)
    }
    catch {
        Set-Location .
    }

    Start-Transcript -Path "$pwd\install.log" -IncludeInvocationHeader | Out-Null

    Set-Time

    while (($choice -ne 'attacker') -and ($choice -ne 'victim')) {
        $choice = Read-Host -Prompt "Is this an 'attacker' or 'victim'?"
    }
    if ($choice -eq 'attacker') {
        # Need a better solution eventually to finding the appropriate config.ini
        $ini_path = (Get-ChildItem -Path . -Recurse -Include "*config.ini*").FullName
        $ini = (Get-Content -Path $ini_path -Raw) -replace 'victim','attacker'
        $ini | Set-Content -Path $ini_path
    }

    Parse-Configuration

    Start-EDR $true

    Start-Auditpol

    Start-PSLogging

    Set-Xauth

    Start-Keylogger $true

    Start-DesktopCapture $true

    Start-PacketCapture $true
    
    if ($Shortcuts) {
        Set-Shortcuts
    }

    Out-File -FilePath .installed
    Write-Host -ForegroundColor Green "[*] CapAttack has been installed"

    Stop-Transcript | Out-Null
    
    Pop-Location

}
