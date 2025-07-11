function Parse-Configuration 
{

    # https://serverfault.com/questions/186030/how-to-use-a-config-file-ini-conf-with-a-powershell-script
    if ( -not (Test-Path config.ini -PathType Leaf) ) 
    {
        Write-Host -ForegroundColor Yellow "[!] Could not find config.ini -- please reinstall capattack and modify config.ini before you begin"
        throw "Missing Configuration"
    }

    Get-Content "config.ini" | ForEach-Object -begin {$script:config=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True) -and ($k[0].StartsWith("#") -ne $True)) { if ($k[0] -ne 'display_name') {$script:config.Add($k[0], $k[1].ToLower().Trim())} else {$script:config.Add($k[0], $k[1].Trim())} } }

    # Set Victim/Attacker Quick Lookup Variables
    if ($config.machine_type -eq "attacker")
    {
        $Script:IsVictim = $false
        $Script:IsAttacker = $true
    }
    else # $config.machine_type -eq "victim"
    {
        $Script:IsVictim = $true
        $Script:IsAttacker = $false
    }

}

function IsCapAttackInstalled
{
    # Check if dependencies have been installed, and thus should not be uninstalled
    if ( Test-Path .installed -PathType Leaf ) 
    {
        $Script:installed = $true;
    }
}

function SHA256 
{

    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $inputstr
    )

    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($inputstr))

    $hashString = [System.BitConverter]::ToString($hash)
    return $hashString.Replace('-', '').ToLower()

}

function IsFfmpegRunning 
{

    if ( (Get-Process -Name ffmpeg -ErrorAction SilentlyContinue).Count -gt 0 ) 
    {
        return $true
    } 
    else 
    {
        return $false
    }

}

function IsFileLocked 
{

    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $filePath
    )

    # Check if file exists; if it doesn't it can't be locked
    if ( -not (Test-Path $filePath -PathType Leaf))
    {
        return $false
    }

    Rename-Item $filePath $filePath -ErrorVariable errs -ErrorAction SilentlyContinue
    return ($errs.Count -ne 0)

}

function Start-ProcessEnhanced
{

    <# 
    Unfortunately, PowerShell's native "Start-Process" cmdlet has issues.
    In order to capture the ExitCode, we must specify -PassThru
    And in order to capture Standard Out/Error, we must specify -RedirectStandardOutput
    and -RedirectStandardError and dump it to a file.
    #>

    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,

        [Parameter(Mandatory=$true)]
        [string]
        $Arguments
    )

    if ( (Test-Path $FilePath -PathType Leaf) -or (Test-Path "$Env:WinDir\system32\$FilePath" -PathType Leaf) )
    {

        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WindowStyle "Hidden" -PassThru -Wait -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt
        $process.WaitForExit();

        $stdout = Get-Content stdout.txt
        Remove-Item stdout.txt -Force

        $stderr = Get-Content stderr.txt
        Remove-Item stderr.txt -Force

        return [pscustomobject]@{
            stdout = $stdout
            stderr = $stderr
            ExitCode = $process.ExitCode
        }

    }
    else 
    {
        # File Not Found
        return $false
    }

}
function Start-ProcessEnhancedv2
{

    <# 
    This is the better .NET implementation for "Start-ProcessEnhanced". However, windows-kill.exe crashes
    and does not return any error.  When it crashes, it crashes hard and stops executing the rest of
    "Stop-Capattack".
    #>

    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,

        [Parameter(Mandatory=$true)]
        [string]
        $Arguments
    )

    if ( (Test-Path $FilePath -PathType Leaf) -or (Test-Path "$Env:WinDir\system32\$FilePath" -PathType Leaf) )
    {

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $FilePath # needs a full path specified, unless the file is within system32
        $pinfo.WorkingDirectory = $PSScriptRoot
        $pinfo.Arguments = $Arguments
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo

        try 
        {
            $p.Start() | Out-Null
            # Crash happens here, but for some reason the exception does not get thrown

            # To avoid deadlocks, always read the output stream first and then wait. 
            $stdout = $p.StandardOutput.ReadToEnd()
            $stderr = $p.StandardError.ReadToEnd()
    
            $p.WaitForExit() | Out-Null # Ensure streams are flushed
            $p.Kill()
        }
        catch
        {
            throw
        }

        return [pscustomobject]@{
            stdout = $stdout
            stderr = $stderr
            ExitCode = $p.ExitCode
        }

    }
    else 
    {
        # File Not Found
        return $false
    }

}

function Find-ProgramFiles 
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    # Using env:ProgramFiles when running as x86 it returns the x86 path so we need a different method
    if  (Test-Path (Join-Path -path "$env:SystemDrive\Program Files\" -ChildPath $Path)) {
        return (Join-Path -path "$env:SystemDrive\Program Files\" -ChildPath $Path)
    }

    if  (Test-Path "${env:ProgramFiles(x86)}\$Path") {
        return "${env:ProgramFiles(x86)}\$Path"
    }
}

function Get-DesktopScaleFilter
{
    Param (
        [Parameter(Mandatory=$true)]
        [int]
        $screenWidth,

        [Parameter(Mandatory=$true)]
        [int]
        $screenHeight
    )

    # FullHD
    $maxWidth = 1920
    $maxHeight = 1080

    <#
    # https://amiaopensource.github.io/ffmprovisr/#SD_HD
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1"
    
    # if you want ffmpeg to calculate the width or height while maintaining the aspect ratio, there's a shortcut
    # where you can substitute -1; if you're encoding with x264 and you need an even number of pixels, there's
    # another shortcut where you can substitute -2.

    # Example: take a 1280x720 video and scale it to 1920 width
    -vf "scale=1920:-2"

    # Add letter or portraitbox to ensure a 16:9 aspect ratio
    -vf "pad=ih*16/9:ih:(ow-iw)/2:(oh-ih)/2"

    # Scale to 1080p and add portrait or letterboxing
    -vf "scale=w=1920:h=1080:force_original_aspect_ratio=1,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"

    # https://superuser.com/questions/891145/ffmpeg-upscale-and-letterbox-a-video
    -vf "scale=(iw*sar)*min(1920/(iw*sar)\,1080/ih):ih*min(1920/(iw*sar)\,1080/ih), pad=1920:1080:(1920-iw*min(1920/iw\,1080/ih))/2:(1080-ih*min(1920/iw\,1080/ih))/2"
    #>

    # Scale width first
    if ($screenWidth -gt $maxWidth) {

        $width = $maxWidth
        # height must be an even number of pixels
        $height = [math]::round( (($screenHeight * $maxWidth) / $screenWidth) / 2 ) * 2

        # Scale height, if needed (e.g, user has monitor in portrait vs. lanscape position)
        if ($height -gt $maxHeight) {

            $height = $maxHeight
            # width must be an even number of pixels
            $width = [math]::round( (($screenWidth * $maxHeight) / $screenHeight) / 2 ) * 2

            return -join('-vf "scale=-2:', $maxHeight, '"')

        }

        return -join('-vf "scale=', $maxWidth, ':-2"')

    }

    # Apply padding of 1px if width or height are odd
    if ( ($screenHeight % 2 -eq 0) -or ($screenWidth % 2 -eq 0) ) {

        return '-vf "pad=ceil(iw/2)*2:ceil(ih/2)*2"'

    }

    
    # No filter needed, return an empty string
    return ""

}
function Export-LinuxLog
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]
        $FilePath,

        [Parameter(Mandatory=$true)]
        [String]
        $ExportName,

        [Parameter(Mandatory=$false)]
        [String]
        $DateFormat,

        [Parameter(Mandatory=$false)]
        [String]
        $DategrepFormat,

        [Parameter(Mandatory=$false)]
        [String]
        $ExtraFormatting
    )
    if([string]::IsNullOrWhiteSpace($DateFormat))
    {
        $DateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    If (Test-Path -Path $FilePath) { 
        Write-Host "[*] Exporting $ExportName..."
        $StartTime = (Get-Date -Date $session.start_time).ToUniversalTime().tostring($DateFormat)
        $EndTime = (Get-Date -Date $session.end_time).ToUniversalTime().tostring($DateFormat)
        $OutFile = $(Join-Path -Path $Guid/logs -ChildPath $ExportName)
        try{
            if ($dategrepFormat) {
                $process = Invoke-Expression -Command "$pwd/lib/dategrep --format='$DategrepFormat' --from='$StartTime' --to='$EndTime' $FilePath $ExtraFormatting"
            } else {
                $process = Invoke-Expression -Command "$pwd/lib/dategrep --from='$StartTime' --to='$EndTime' $FilePath $ExtraFormatting"
            }
        } catch {
            Write-Host -ForegroundColor Yellow "[!] Failed to export $ExportName."
        }
        $process | Out-File -Append -Encoding ASCII -FilePath $OutFile
    }
}

function Set-Shortcuts
{
    Param (
        [Parameter(Mandatory=$false)]
        [String]
        $Headless
    )
    if ($Headless) {
        $LogonType = "S4U"
    } else {
        $LogonType = "Interactive"
    }
    if (Get-ScheduledTask -TaskName "Start-Capattack" -ErrorAction SilentlyContinue){
        Unregister-ScheduledTask -TaskName "Start-Capattack" -Confirm:$false | Out-Null
        Unregister-ScheduledTask -TaskName "Stop-Capattack" -Confirm:$false | Out-Null
    }
    $principal = New-ScheduledTaskPrincipal -LogonType $LogonType -RunLevel Highest -UserId $env:USERNAME
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "cd $pwd;import-module .\capattack.psd1;Start-Capattack" -WorkingDirectory "$pwd"
    Register-ScheduledTask -TaskName "Start-Capattack" -Action $action -Principal $principal | Out-Null
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "cd $pwd;import-module .\capattack.psd1;Stop-Capattack" -WorkingDirectory "$pwd"
    Register-ScheduledTask -TaskName "Stop-Capattack" -Action $action -Principal $principal | Out-Null
    # create profile if it doesn't exist https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.4#how-to-create-a-profile
    if (!(Test-Path -Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force
    }
    if (-not (Select-String -Path $PROFILE -Pattern "CapAttack")) {
        $profile_data = Get-Content $PROFILE
        $profile_data = $profile_data + '
function Start-Capattack { Start-ScheduledTask -TaskName Start-Capattack;DO {$State = Get-ScheduledTask -TaskName Start-Capattack} Until ($State.State -eq "Ready");Write-Host "CapAttack Started"}
function Stop-Capattack { Start-ScheduledTask -TaskName Stop-Capattack;DO {$State = Get-ScheduledTask -TaskName Stop-Capattack} Until ($State.State -eq "Ready");Write-Host "CapAttack Stopped"}'
        $profile_data | set-content -encoding UTF8 $PROFILE
        }
    Write-Host "[+] CapAttack added to Powershell"
}