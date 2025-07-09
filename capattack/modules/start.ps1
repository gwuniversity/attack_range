function Capattack-Start {
    Start-Capattack @args
}

function Start-Capattack 
{
    Param (
        [Parameter(Position=0, Mandatory=$false)]
        [switch]
        $Headless
    )

    Push-Location
    Set-Location (Split-Path (Get-Module capattack).Path -Parent)

    if ($IsLinux){
        If (-not(Test-Path /root/.Xauthority)) {
            Copy-Item /home/$sudoer/.Xauthority /root/.Xauthority
        }
    }

    try {
        Start-Transcript -Path "$pwd\debug.log" -IncludeInvocationHeader -ErrorAction Stop | Out-Null
    } catch {
        # Method to properly start the transcript if something didn't shut down correctly
        # https://stackoverflow.com/questions/46692735/powershell-transcript-errors-when-transcript-is-already-running
        Start-Transcript -Path "$pwd\debug.log" -IncludeInvocationHeader | Out-Null
    }

    Parse-Configuration
    if ($config.headless.ToLower() -ne "false"){
        $Headless = $true
    }

    # Check if session is recording
    if (Test-Path .activesession -PathType Leaf) 
    {

        Write-Host -ForegroundColor Yellow  "[!] An active session is in progress."
        if ($Headless) {
            $confirmation = "y"
        } else {
            $confirmation = Read-Host "Do you want to clear the current session and start a new one? y/N"
        }

        if ( ($confirmation.ToLower().Trim() -eq 'y') -or ($confirmation.ToLower().Trim() -eq 'yes' ) ) 
        {
            Stop-Capattack $true
        } 
        else 
        {
            return
        }

    }

    IsCapAttackInstalled

    if ( -not ($installed) )
    {
        Set-Time
    }


    if ( $IsWindows ) {
        Write-Host "[*] Collecting system information..."
        Start-Job -Init ([ScriptBlock]::Create("Set-Location '$pwd'")) -ScriptBlock {systeminfo > systeminfo.txt} | Out-Null
    }

    Get-ProcessList

    Set-Xauth

    Start-PacketCapture

    Start-Keylogger

    Clear-EventLogs

    Start-EDR

    if ( -not ($installed) )
    {
        Start-Auditpol

        Start-PSLogging
    }

    Start-DesktopCapture

    Start-Session

    Stop-Transcript | Out-Null

    Pop-Location

}

function Set-Time {

    # Set Timezone
    Write-Host "[*] Setting timezone to UTC and showing seconds on clock"

    # Show seconds on clock
    if ($IsWindows)
    {
        # Get-TimeZone was added to PowerShell 5.1
        # tzutil has been shipped since Windows 7

        <#
        Get-TimeZone | Select-Object -ExpandProperty Id | Out-File .tz -Encoding ASCII
        Set-TimeZone -Id "UTC"
        #>
        tzutil /g > .tz
        tzutil /s "UTC"

        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSecondsInSystemClock" -Value 1 -PropertyType "DWORD" -force | Out-Null
        Get-ItemPropertyValue -Path "HKCU:\Control Panel\International" -Name "sTimeFormat" | Out-File .timeformat -Encoding ASCII
        New-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sTimeFormat" -Value "HH:mm:ss" -PropertyType "String" -force | Out-Null
        Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force # requires explorer to be restarted

        # NOTE: This is required because Get-Date and [DateTime]::Now are not timezone aware
        # They determine the timestamp when powershell is launched, but won't update if the timezone is changed while powershell is running
        [System.TimeZoneInfo]::ClearCachedData()
    } 
    elseif ($IsLinux) 
    {

        # https://superuser.com/questions/309034/how-to-check-which-timezone-in-linux
        # timedatectl show --va -p Timezone

        # Debian
        if (Test-Path "/etc/timezone" -PathType Leaf)
        {
            (cat /etc/timezone) | Out-File .tz -Encoding ASCII
            timedatectl set-timezone "UTC" > $null
            if ($IsVictim) {
                service syslog restart > /dev/null 2>&1
                service auditd restart > /dev/null 2>&1
            }

        }
        # CentOS/RHEL
        elseif (Test-Path "/etc/localtime" -PathType Leaf) 
        {
            (cat /etc/localtime) | Out-File .tz -Encoding ASCII
            timedatectl set-timezone "UTC" > $null
            if ($IsVictim) {
                service syslog restart > /dev/null 2>&1
                service auditd restart > /dev/null 2>&1
            }
        }
        
        if ($sudoer)
        {

            # TODO: determine the desktop environmnet (hard to do programmatically, lots of guesswork)
            # We will assume that they are using XFCE, the default for Kali

            # XFCE
            # Defaults to "%I:%M %p"
            # Don't run xfconf-query as root. It needs to be run as a regular user so it can connect to the xfconfd daemon instance running under your user profile.
            # https://forum.xfce.org/viewtopic.php?id=10870
            # https://askubuntu.com/questions/805455/xfconf-query-crontab-failed-to-init-libxfconf-unable-to-autolaunch-a-dbus-da
            <#
            PLUGIN=`cat ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml | grep clock | awk -F'"' '{print $2}'`
            xfconf-query -c xfce4-panel -p /plugins/$PLUGIN/digital-format -n -t string > .dateformat
            xfconf-query -c xfce4-panel -p /plugins/$PLUGIN/digital-format -s "%k:%M:%S %Z"
            #>
            
            if (Test-Path "$( getent passwd "$sudoer" | cut -d: -f6 )/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" -PathType Leaf) {
                # Assume XFCE
                $plugin = Invoke-Expression -Command "cat $( getent passwd "$sudoer" | cut -d: -f6 )/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml | grep clock | awk -F'\`"' '{print `$2}'"
                Invoke-Expression -Command "cat $( getent passwd "$sudoer" | cut -d: -f6 )/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml | grep 'digital-time-format' | awk -F'\`"' '{print `$6}' > .dateformat" | Out-Null
                Invoke-Expression -Command "pkexec --user $sudoer env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $sudoer)/bus xfconf-query -c xfce4-panel -p /plugins/$plugin/digital-time-format -n -t string -s `"%k:%M:%S %Z`"" | Out-Null
            } else {
                # Assume Gnome
                apt install dbus-x11 -y > /dev/null 2>&1
                Invoke-Expression -Command "gsettings get org.gnome.desktop.interface clock-show-seconds" | Out-Null
                Invoke-Expression -Command "gsettings set org.gnome.desktop.interface clock-show-seconds true" | Out-Null
            }

        }

    } 
    elseif ($IsMacOS)
    {

        # Change timezone
        # NOTE: We need to trim the string "Time Zone: " from the response (hence the cut 12 characters)
        # NOTE: UTC is not a valid timezone; it's GMT on mac
        (systemsetup -gettimezone | cut -c12-) | Out-File .tz -Encoding ASCII
        (systemsetup -settimezone "GMT")
        
        # Default appears to be "EEE MMM d  j:mm a", but we should back theirs up and then restore it
        # NOTE: we need to drop privs for these commands to it changes the user's plist

        # These are in ~/Library/Preferences/
        if ($sudoer)
        {
            # https://github.com/tech-otaku/menu-bar-clock
            Invoke-Expression -Command "sudo -u $sudoer defaults read com.apple.menuextra.clock.plist DateFormat > .dateformat"
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist DateFormat -string ""HH:mm:ss"""
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist IsAnalog -bool false"
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist ShowDayOfWeek -bool false"
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist ShowDayOfMonth -bool false"
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist Show24Hour -bool true"
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist ShowSeconds -bool true"
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist ShowAMPM -bool false"

            # Pre Big Sur
            # killall SystemUIServer
            killall ControlCenter

        }

    }

}

function Start-EDR 
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $install = $false
    )

    # Install, configure, start sysmon
    if ( ($config.edr -eq "sysmon") -and $IsWindows -and $IsVictim ) 
    {
        
        Write-Host "[*] Installing sysmon..."

        # Look for already downloaded sysmon64 or sysmon
        $sysmon_path = "$pwd\lib\sysmon64.exe"
        if ( -not (Test-Path $sysmon_path -PathType Leaf) ) 
        {
            $sysmon_path = "$pwd\lib\sysmon.exe"
            if ( -not (Test-Path $sysmon_path -PathType Leaf) ) 
            {

                # Grab sysmon
                Write-Host "[*] Downloading sysmon..."
                (New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Sysmon.zip", "$pwd\lib\Sysmon.zip")
                Expand-Archive -path '.\lib\Sysmon.zip' -destinationpath '.\lib\'
                Remove-Item -path '.\lib\Sysmon.zip'

                if ([Environment]::Is64BitOperatingSystem) 
                {
                    $sysmon_path = "$pwd\lib\sysmon64.exe"
                } 
                else 
                {
                    $sysmon_path = "$pwd\lib\sysmon.exe"
                }

                if ( -not (Test-Path $sysmon_path -PathType Leaf) ) 
                {
                    Write-Host -ForegroundColor Yellow "[!] Could not find sysmon64.exe or sysmon.exe -- please manually install it to the lib directory"
                    throw "Missing sysmon"
                }
            }
        }
        if ( -not (Test-Path .sysmon -PathType Leaf) ){
            # Installs sysmon into the "off" position
            # Load the config that doesn't log anything
            $process = Start-ProcessEnhanced -FilePath $sysmon_path -Arguments "-accepteula -h md5,sha256,imphash,sha1 -n -i $pwd\sysmon_off.xml"
            # TODO: better error handling if sysmon fails to install
            if ($process.ExitCode -eq 1242)
            {
                if ($Headless) {
                    $confirmation = "n"
                } else {
                    $confirmation = Read-Host "[!] Sysmon detected. Do you want to replace (Y/n)?"
                }
                if ( ($confirmation.ToLower().Trim() -ne 'n') -or ($confirmation.ToLower().Trim() -ne 'no') ) 
                {
                    if (Test-Path "C:\Windows\sysmon.exe" -PathType Leaf) { 
                        $sysmon_uninstall = Start-ProcessEnhanced -FilePath "$env:windir\sysmon.exe" -Arguments "-u"
                    } elseif (Test-Path "C:\Windows\sysmon64.exe" -PathType Leaf) {
                        $sysmon_uninstall = Start-ProcessEnhanced -FilePath "$env:windir\sysmon64.exe" -Arguments "-u"
                    } else {
                        Write-Host -ForegroundColor Yellow "[!] Could not find installed Sysmon -- please manually uninstall before continuing"
                        throw "Sysmon already running"
                    }
                    if ($sysmon_uninstall.ExitCode -ne 0)
                    {
                        Write-Host -ForegroundColor Yellow "[!] Could not uninstall automatically -- please manually uninstall the current configuation before continuing"
                        throw "Sysmon already running"
                    }
                    
                    $process = Start-ProcessEnhanced -FilePath $sysmon_path -Arguments "-accepteula -h md5,sha256,imphash,sha1 -n -i $pwd\sysmon_off.xml"
                }
            }
            elseif ($process.ExitCode -ne 0)
            {
                Write-Host -ForegroundColor Yellow "[!] Failed to turn off sysmon (Code $($process.ExitCode): $($process.stdout)). Please review the sysmon_off.xml configuration file."
                throw "Sysmon configuration error"
            }
            Out-File -FilePath .sysmon
        }
        # Increase size of sysmon event log to 500 MB
        $maxlength = Get-WinEvent -ListLog Microsoft-Windows-Sysmon/Operational
        if ($maxlength -ne 524288000) 
        {
            $maxlength.MaximumSizeInBytes = 524288000
            $maxlength.SaveChanges()
        }

        if ( -not $install )
        {
            # Start sysmon with configuration
            if ( -not (Test-Path $config.sysmon_config -PathType Leaf) ) 
            {
                Write-Host -ForegroundColor Yellow "[!] Could not find sysmon configuration -- please check the 'sysmon_config' setting in config.ini"
                throw "Missing sysmon configuration"
            }

            $process = Start-ProcessEnhanced -FilePath $sysmon_path -Arguments "-c $pwd\$($config.sysmon_config)"
            # https://stackoverflow.com/questions/49375418/start-process-redirect-output-to-null
            <#
            $process = Start-Process -NoNewWindow -FilePath $sysmon_path -ArgumentList "-c $($config.sysmon_config)" -PassThru -Wait -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
            Remove-Item -Path stdout.txt
            Remove-Item -Path stderr.txt
            #>
            if ($process.ExitCode -ne 0)
            {
                Write-Host -ForegroundColor Yellow "[!] Sysmon configuration failed to install (Code $($process.ExitCode): $($process.stdout)). Double check the sysmon binary exists and the configuration is correct"
                throw "Sysmon failed to install"
            }

            Write-Host "[*] Sysmon has been installed and the $($config.sysmon_config) configuration loaded"

        }

    } 
    elseif ( ($config.edr -eq "none") -or ($config.edr -eq "") -and $IsVictim ) 
    {

        Write-Host "[*] No EDR configured -- you will have to manually retrieve event logs for this session"

    } 
    elseif ( ($config.edr -eq "sysmon") -and $IsLinux -and $IsVictim )
    {
        # Might need better error handling. Start-Process(Enhanced) doesn't seem to return exit codes on Ubuntu
        Write-Host "[*] Installing sysmon..."
        try {
            Invoke-Expression -Command "sysmon -h >/dev/null 2>&1" 
        } catch {
            if (($PsVersionTable.OS.Contains('Ubuntu')) -or ($PsVersionTable.OS.Contains('Kali')))
            {
                Write-Host "[*] Downloading Sysmon..."
                Invoke-Expression -Command "wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb"
                Invoke-Expression -Command "dpkg -i packages-microsoft-prod.deb"
                Invoke-Expression -Command "apt-get update"
                Invoke-Expression -Command "apt-get install sysinternalsebpf -y"
                Invoke-Expression -Command "apt-get install sysmonforlinux -y"
                Write-Host "[*] Installing auditd..."
                Invoke-Expression -Command "apt-get install auditd -y"
                Invoke-Expression -Command "wget https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules -O /etc/audit/rules.d/audit.rules"
                Invoke-Expression -Command "service auditd restart"
            } 
            elseif ($PSVersionTable.OS.Contains('Linux') -or $PSVersionTable.OS.Contains('CentOS')) {
                Write-Host "[*] Downloading Sysmon..."
                Invoke-Expression -Command "yum install sysinternalsebpf -y"
                Invoke-Expression -Command "yum install sysmonforlinux -y"
                Write-Host "[*] Installing auditd..."
                Invoke-Expression -Command "yum install auditd -y"
                Invoke-Expression -Command "wget https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules -O /etc/audit/rules.d/audit.rules"
                Invoke-Expression -Command "service auditd restart"
            }
            else
            {
                Write-Host -ForegroundColor Yellow "[!] Sysmon for linux currently only supported for Ubuntu and RHEL8+"
                throw "Unsupported OS"
            }
        }

        if ( -not (Test-Path .sysmon -PathType Leaf) ){
            
            # Installs sysmon into the "off" position
            # Load the config that doesn't log anything
            $process = Invoke-Expression -Command "sysmon -accepteula -u 2>&1 > $pwd/.sysmon && sysmon -accepteula -h md5,sha256,imphash,sha1 -n -i $pwd/sysmon_off.xml 2>&1 >> $pwd/.sysmon"
            # TODO: better error handling if sysmon fails to install
            $process = Get-Content $pwd/.sysmon
            if (-Not $process.Contains("Sysmon stopped."))
            {
                Write-Host -ForegroundColor Yellow "[!] Failed to turn off sysmon. Please review the sysmon_off.xml configuration file."
                throw "Sysmon configuration error"
            }
        }

        if ( -not $install )
        {
            # Start sysmon with configuration
            if ( -not (Test-Path $config.sysmon_config -PathType Leaf) ) 
            {
                Write-Host -ForegroundColor Yellow "[!] Could not find sysmon configuration -- please check the 'sysmon_config' setting in config.ini"
                throw "Missing sysmon configuration"
            }

            $process = Invoke-Expression -Command "sysmon -c $pwd/$($config.sysmon_config)"
            if (-Not $process.Contains("Configuration file validated."))
            {
                Write-Host $process
                Write-Host -ForegroundColor Yellow "[!] Sysmon configuration failed to install. Double check the sysmon binary exists and the configuration is correct"
                throw "Sysmon failed to install"
            }

            Write-Host "[*] Sysmon has been installed and the $($config.sysmon_config) configuration loaded"
        }


    }

}

function Start-Auditpol
{

    # Install, configure auditpol
    if ( ($config.auditpol -eq "true") -and $IsWindows -and $IsVictim )
    {

        Write-Host "[*] Configuring auditpol..."

        ## Thanks CCDC blue teamers for the inspiration!
        <#
        https://github.com/UMGC-CCDC/UMGC-CCDC.github.io/blob/56929fa44acc986a8e893f938c2b198669a40507/war.ps1
        https://github.com/UMGC-CCDC/CCDC2021/blob/ce24420c0af74060addf8eecb0f0533b479ad5c4/win_script.cmd
        https://github.com/PaddyPooskie/DruryCCDC/blob/7a5bf8adbb7cc0cae43482bb7b9a2bb2d9455896/Scripts/logging.bat
        #>

        ## Greetz Cyb3rWard0g
        ## https://github.com/OTRF/Blacksmith/blob/master/resources/scripts/powershell/auditing/Enable-WinAuditCategories.ps1

        ## List all options
        <#
        auditpol /list /category /r
        auditpol /list /subcategory:* /r
        #>

        # Remove any config backups we previously made but didn't delete
        if (Test-Path auditpol_backup.csv -PathType Leaf) 
        {
            Remove-Item -Path auditpol_backup.csv
        }

        # Backup their current config
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/backup /file:$pwd\auditpol_backup.csv" 

        <#
        $process = Start-Process -NoNewWindow -FilePath auditpol.exe -ArgumentList "/backup /file:$($pwd)\auditpol_backup.csv" -PassThru -Wait -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
        Remove-Item -Path stdout.txt
        Remove-Item -Path stderr.txt
        #>

        # TODO: better error handling 
        if ($process.ExitCode -eq 80) 
        {
            Write-Host -ForegroundColor Yellow "[!] auditpol backup already exists"
        } 
        elseif ($process.ExitCode -ne 0) 
        {
            Write-Host -ForegroundColor Yellow "[!] auditpol failed to backup the existing configuration"
        }

        # We're going to just log ALL THE THINGS
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Account Logon`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Account Management`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Detailed Tracking`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"DS Access`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Logon/Logoff`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Object Access`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Policy Change`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"Privilege Use`" /success:enable /failure:enable"
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/set /category:`"System`" /success:enable /failure:enable"

        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "scenoapplylegacyauditpolicy" -Value 1 -PropertyType "DWORD" -force | Out-Null
        New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -PropertyType "DWORD" -force | Out-Null

        # TODO: add image hash for 4688

        Write-Host "[*] Configured auditpol to log everything"

    } 

}

function Start-PSLogging {

    # Install, configure powershell logs
    if ( ($config.powershell_module_scriptblock -eq "true") -and $IsWindows -and $IsVictim )
    {

        Write-Host "[*] Configuring powershell module and script block logging..."

        ## Greetz Cyb3rWard0g
        ## https://github.com/OTRF/Blacksmith/blob/master/resources/scripts/powershell/auditing/Enable-PowerShell-Logging.ps1

        # TODO: check $PSVersionTable and determine if module/script logging can be configured

        # Registry paths may not exist
        if ( -not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell") ) 
        {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Force | Out-Null
        }
        if ( -not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging") ) 
        {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
        }
        if ( -not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging") ) 
        {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force | Out-Null
        }
        if ( -not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames") ) 
        {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force | Out-Null
        }

        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -PropertyType "DWORD" -force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockInvocationLogging" -Value 1 -PropertyType "DWORD" -force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableScriptBlockLogging" -Value 1 -PropertyType "DWORD" -force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Name "*" -Value "*" -PropertyType "String" -force | Out-Null

        Write-Host "[*] Configured powershell module and script block logging"

    } 

}

function Start-Keylogger
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $install = $false
    )

    # Start keylogger
    if ($config.keystrokes -eq "true") 
    {

        if ($IsWindows)
        {
            if ([System.Environment]::OSVersion.Version.Major -lt 7) 
            {
                Write-Host -ForegroundColor Yellow "[!] This OS doesn't support keylogging..."
            }
            else 
            {
                Write-Host "[*] Installing keylogger..."

                # Look for already installed keylogger
                $keylogger_path = ".\lib\keylogger.exe"
                if ( -not (Test-Path $keylogger_path -PathType Leaf) ) 
                {
                    
                    # Grab keylogger
                    Write-Host "[*] Downloading keylogger..."
                    (New-Object System.Net.WebClient).DownloadFile("https://cdn.snapattack.com/resources/capattack/keylogger.exe", "$pwd\lib\keylogger.exe")

                    if ( -not (Test-Path $keylogger_path -PathType Leaf) )
                    {
                        Write-Host -ForegroundColor Yellow "[!] Could not find keylogger.exe -- please manually install it to the lib directory"
                        throw "Missing keylogger"
                    }

                }

                if ( -not $install )
                {

                    Start-Process -WindowStyle hidden -FilePath $keylogger_path | Out-Null

                    Write-Host "[*] Keylogger started"

                }
            }
        }
        elseif ($IsLinux)
        {
            
            Write-Host "[*] Installing keylogger..."

            # Look for already installed keylogger
            $keylogger_path = "./lib/keylogger"
            if ( -not (Test-Path $keylogger_path -PathType Leaf) ) 
            {
                
                # Grab keylogger
                Write-Host "[*] Downloading keylogger..."
                (New-Object System.Net.WebClient).DownloadFile("https://cdn.snapattack.com/resources/capattack/keylogger.bin", "$pwd/lib/keylogger")

                if ( -not (Test-Path $keylogger_path -PathType Leaf) )
                {
                    Write-Host -ForegroundColor Yellow "[!] Could not find keylogger -- please manually install it to the lib directory"
                    throw "Missing keylogger"
                }

                # On Linux, we must make the file executable
                chmod +x ./lib/keylogger

            }

            if ( -not $install )
            {

                # This outputs a background job table if run as a regular bash coommand inside powershell
                Invoke-Expression -Command "nohup ./lib/keylogger >/dev/null 2>&1 &" | Out-Null

                Write-Host "[*] Keylogger started"

            }

        }
        elseif ($IsMacOS)
        {

            # Unsupported
            Write-Host -ForegroundColor Yellow "[!] Keystroke logging is not currently supported for MacOS"

        }

    } 

}

function Start-DesktopCapture
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $install = $false
    )

    # Start ffmpeg
    if ($config.desktop -eq "true")
    {

        if ($IsWindows)
        {

            # Check screen resolution
            Add-Type -AssemblyName System.Windows.Forms
            $PMS = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize

            if (($PMS.Width -gt 1920) -or ($PMS.Height -gt 1080)) {
                Write-Host -ForegroundColor Yellow "[WARNING] Your desktop resolution, $($PMS.Width)x$($PMS.Height), is above Full HD (1920x1080). Desktop capture may take up significant CPU/memory and framerate may suffer. We will downscale and capture at Full HD resolution."
            }

            Write-Host "[*] Installing desktop capture..."

            # Look for already installed ffmpeg
            $ffmpeg_path = ".\lib\ffmpeg.exe"
            if ( -not (Test-Path $ffmpeg_path -PathType Leaf) ) 
            {

                # Grab ffmpeg
                Write-Host "[*] Downloading ffmpeg..."
                # Built from https://github.com/FFmpeg/FFmpeg/tree/1eaa575cf11c054b0b724480f3070fc908faf8ef with gdigrab.c modification to CAPTUREBLT
                (New-Object System.Net.WebClient).DownloadFile("https://cdn.snapattack.com/resources/capattack/ffmpeg.exe", "$pwd\lib\ffmpeg.exe")
                if ( -not (Test-Path $ffmpeg_path -PathType Leaf) ) 
                {
                    Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg.exe -- please manually install it to the lib directory"
                    throw "Missing ffmpeg"
                }

            }
            # Look for already installed ffmpeg_wrap
            $ffmpeg_wrap_path = ".\lib\ffmpeg_wrap.exe"
            if ( -not (Test-Path $ffmpeg_wrap_path -PathType Leaf) )
            {

                # Grab ffmpeg_wrap
                Write-Host "[*] Downloading ffmpeg_wrap..."
                # Built from https://github.com/RattleyCooper/ffmpeg_wrapper/tree/b8257e68e03809442a15dbd38b1a8d3751bd0b6f
                (New-Object System.Net.WebClient).DownloadFile("https://cdn.snapattack.com/resources/capattack/ffmpeg_wrap.exe", "$pwd\lib\ffmpeg_wrap.exe")
                if ( -not (Test-Path $ffmpeg_wrap_path -PathType Leaf) )
                {
                    Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg_wrap.exe -- please manually install it to the lib directory"
                    throw "Missing ffmpeg_wrap"
                }

            }

            if ( -not $install )
            {

                # TODO:
                # _ handle multiple displays
                # - adjust resolution / filesize / container

                if ($config.ffmpeg_recorder -eq "dshow") 
                {

                    # try a dshow method, like https://github.com/rdp/screen-capture-recorder-to-video-windows-free
                    # https://github.com/AzzyC/scripts/blob/8c00e1f31ab9d8c71f608858f826b692ee4d9c11/priv/screenrecord.sh
                    # https://github.com/ShareX/ShareX/tree/master/Lib

                    # TODO: Assume Visual C++ Redist 2010 is installed
                    # https://www.microsoft.com/en-us/download/details.aspx?id=26999
                    # Get-CIMInstance -Class Win32_Product -Filter "Name LIKE '%Visual C++ 2010%'"

                    # https://github.com/obsproject/libdshowcapture

                    # Register Dlls
                    #$dlls = (Get-ChildItem -path .\lib -include '*.dll' -recurse).fullname
                    
                    #foreach ($dll in $dlls) 
                    #{
                    #    $null = Start-Process -WindowStyle hidden -FilePath regsvr32 -ArgumentList "/s /i $dll" -PassThru -Wait | Out-Null
                    #}
                    # Register UScreenConnect
                    if (-not (Get-WmiObject -Class Win32_Product | sort-object Name | select Name | where { $_.Name -match "UScreenCapture"})) {
                        Write-Host -ForegroundColor Yellow "[!] Could not find UScreenCapture video device; please install UScreenCapture (http://www.umediaserver.net/bin/UScreenCapture(x64).zip) or use gdigrab instead"
                        throw "Missing ffmpeg video device"
                    }
                    $null = Start-Process -WindowStyle hidden -FilePath $ffmpeg_path -ArgumentList "-hide_banner -list_devices true -f dshow -i dummy" -PassThru -Wait -RedirectStandardError stderr.txt

                    if (Select-String -Path stderr.txt -pattern "UScreenCapture")
                    {
                        if (Select-String -Path stderr.txt -pattern "UScreenCapture.*(none)") {
                            Write-Host -ForegroundColor Yellow "[!] Dshow filter in a bad state. Uninstall and reinstall UScreenCapture"
                            #Filter got in a bad state from ffmpeg being forcible closed
                            throw "Bad dshow filter state"

                        }

                    } 

                } 
                else 
                { # use gdigrab

                    # gdigrab will fail if a UAC prompt is raised, because of UiPI / Secure Desktop
                    # so we must disable the dimming of UAC prompts to use this method
                    # https://stackoverflow.com/questions/43886350/ffmpeg-fails-to-capture-desktop-when-uac-prompt-appears

                    # Turn off Secure Desktop
                    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value "0" -PropertyType "DWORD" -force | Out-Null

                    $filters = Get-DesktopScaleFilter $PMS.Width $PMS.Height
                    Start-Process -WindowStyle hidden -FilePath $ffmpeg_wrap_path -ArgumentList "$ffmpeg_path -y -rtbufsize 100M -f gdigrab -probesize 10M -i desktop -c:v libx264 $filters -preset veryfast -tune zerolatency -crf 21 -pix_fmt yuv420p capattack_session.mkv" | Out-Null

                }

                Write-Host "[*] Desktop capture started"

            }

        }
        elseif ($IsLinux)
        {

            # Check screen resolution
            $width = [int] $(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f1)
            $height = [int] $(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f2)

            if (($width -gt 1920) -or ($height -gt 1080)) {
                Write-Host -ForegroundColor Yellow "[WARNING] Your desktop resolution, $($width)x$($height), is above Full HD (1920x1080). Desktop capture may take up significant CPU/memory and framerate may suffer. We will downscale and capture at Full HD resolution."
            }

            Write-Host "[*] Installing desktop capture..."

            # Look for already installed ffmpeg
            if ( -not (which ffmpeg) ) 
            {

                # https://github.com/mikamakusa/Linux-easy-deploy/blob/97da563540bc98428c3b5becbf4c5903741e38f2/test.ps1

                # Grab ffmpeg
                # NOTE: these commands don't like the stdout/err redirection...  >/dev/null 2>&1
                if (which apt) 
                {
                    Write-Host "[*] Installing ffmpeg via apt..."
                    apt update >/dev/null 2>&1
                    apt install ffmpeg -y >/dev/null 2>&1
                }
                elseif (which yum)
                {
                    Write-Host "[*] Installing ffmpeg via yum..."
                    yum check-update >/dev/null 2>&1
                    yum install ffmpeg -y >/dev/null 2>&1
                }
                else
                {
                    Write-Host "[*] Unsupported package manager -- currently only support apt and yum"
                }

                if ( -not (which ffmpeg) ) 
                {
                    Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg -- please manually install it"
                    throw "Missing ffmpeg"
                }

            }

            if ( -not $install )
            {

                # Use x11grab
                # https://trac.ffmpeg.org/wiki/Capture/Desktop
                # This outputs a background job table if run as a regular bash coommand inside powershell
                # NOTE: on linux we need to specify both the framerate to capture and the framerate to output.  Using -r / - framerate alone won't work.
                $filters = Get-DesktopScaleFilter $width $height
                $xdisplay = (Invoke-Expression -Command "cat /proc/$pid/environ | tr '\0' '\n' | grep ^DISPLAY=").Split('=')[1]
            
                # ffmpeg on ubuntu is kind of picky about order of things apparently and requires video_size or won't capture whole screen
                $vsize = Invoke-Expression -Command "xrandr -q --current | grep '*' | cut -d ' ' -f4"
                Invoke-Expression -Command "nohup ffmpeg -nostdin -y -rtbufsize 100M -f x11grab -r 25 -probesize 10M -draw_mouse 1 -show_region 1 -video_size $vsize -i $xdisplay -c:v libx264 $filters -preset veryfast -tune zerolatency -crf 21 -pix_fmt yuv420p capattack_session.mkv >/dev/null 2>&1 &" | Out-Null
            }
        
        }
        elseif ($IsMacOS)
        {

            Write-Host "[*] Installing desktop capture..."

            # Look for already installed ffmpeg
            if ( (Test-Path "./lib/ffmpeg" -PathType Leaf) ) 
            {
                $ffmpeg_path = "./lib/ffmpeg"
            }
            elseif ( (which ffmpeg) ) 
            {
                $ffmpeg_path = (which ffmpeg)
            }
            else 
            {
                $ffmpeg_path = $false
            }

            if ( -not ($ffmpeg_path) )
            {

                # https://github.com/mikamakusa/Linux-easy-deploy/blob/97da563540bc98428c3b5becbf4c5903741e38f2/test.ps1

                # Grab ffmpeg
                if (which brew) 
                {
                    Write-Host "[*] Installing ffmpeg via brew..."
                    brew update >/dev/null 2>&1
                    brew install ffmpeg -y >/dev/null 2>&1
                }
                else
                {
                    Write-Host "[*] Installing statically compiled ffmpeg via zip..."
                    (New-Object System.Net.WebClient).DownloadFile("https://evermeet.cx/ffmpeg/get/zip", "$pwd/lib/ffmpeg.zip")
                    Expand-Archive -path './lib/ffmpeg.zip' -destinationpath './lib/'
                    Remove-Item -path './lib/ffmpeg.zip'
                }

                # Look again for already installed ffmpeg
                if ( (Test-Path "./lib/ffmpeg" -PathType Leaf) ) 
                {
                    $ffmpeg_path = "./lib/ffmpeg"
                }
                elseif ( (which ffmpeg) ) 
                {
                    $ffmpeg_path = (which ffmpeg)
                }
                else 
                {
                    $ffmpeg_path = $false
                }

                if ( -not ($ffmpeg_path) )
                {
                    Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg -- please manually install it"
                    throw "Missing ffmpeg"
                }

            }
            else 
            {
                Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg -- please manually install it"
                throw "Missing ffmpeg"
            }
            
            if ( -not $install )
            {

                # List AVFoundation video devices
                # NOTE: this command does not work; the stderr redirection doesn't seem to work
                # Invoke-Expression -Command "$ffmpeg_path -f avfoundation -hide_banner -list_devices true -i /dev/zero 2>&1 | grep -i ""capture screen""" | Out-String -OutVariable stdout
                
                # NOTE: need to add -Wait otherwise grep will search an empty file
                Start-Process -FilePath $ffmpeg_path -ArgumentList "-f avfoundation -hide_banner -list_devices true -i /dev/zero 2>&1" -RedirectStandardError stderr -RedirectStandardOutput stdout -Wait
                grep -i "capture screen" stderr > stdout
                $stdout = $(cat stdout)
                Remove-Item -Path stdout
                Remove-Item -Path stderr
                <#
                [AVFoundation indev @ 0x7fc152e04c00] AVFoundation video devices:
                [AVFoundation indev @ 0x7fc152e04c00] [0] FaceTime HD Camera (Built-in)
                [AVFoundation indev @ 0x7fc152e04c00] [1] Capture screen 0
                [AVFoundation indev @ 0x7fc152e04c00] AVFoundation audio devices:
                [AVFoundation indev @ 0x7fc152e04c00] [0] MacBook Pro Microphone
                #>

                if ($stdout -match "\[([0-9]*?)\]")
                {
                    $video = $matches[1]
                    
                    # Use avfoundation
                    # https://trac.ffmpeg.org/wiki/Capture/Desktop
                    Invoke-Expression -Command "nohup $ffmpeg_path -y -rtbufsize 100M -f avfoundation -probesize 10M -i ""$video`:none"" -capture_cursor 1 -c:v libx264 -vf ""pad=ceil(iw/2)*2:ceil(ih/2)*2"" -preset veryfast -tune zerolatency -crf 21 -pix_fmt yuv420p capattack_session.mkv >/dev/null 2>&1 &" | Out-Null
                } 
                else
                {
                    Write-Host -ForegroundColor Yellow "[!] No AVFoundation video device found - the desktop will not be captured"
                    throw "No desktop capture available"
                }

            }

        }

    }

}

function Get-ProcessList
{
    # Save current proceses to seed process graph
    if ($IsVictim -and $IsWindows) 
    {

        # To add IntegrityLevel, can use Jared Atkinson's Get-InjectedThread.ps1
        # Not an easy way to query from powershell/WMI
        # https://gist.github.com/jaredcatkinson/23905d34537ce4b5b1818c3e6405c1d2
        # https://github.com/jaredcatkinson/PSReflect-Functions/blob/master/advapi32/GetTokenInformation.ps1



        Write-Host  "[*] Logging all currently running processes"
        

        # TODO: Use Measure-Command to profile for potential improvements
        # Getting the basic process data is less than a second.
        # Getting the hashes is 2.5 seconds.
        # Can we make one call to Get-AuthenticodeSignature instead of two?  That adds about 2.5s per call.

        # $processes = Get-CimInstance -Class Win32_Process | Select-Object -Property ParentProcessId, ProcessId, ProcessName, Path, CommandLine, Description, @{Label='CreationDate'; Expression={$_.CreationDate.toString("yyyy-MM-ddTHH:mm:ss.ffffffZ")}}, @{Label='User'; Expression={if ($_.GetOwner().Domain -and $_.GetOwner().User){$_.GetOwner().Domain+"\"+$_.GetOwner().User}}}, @{Label='MD5'; Expression={(Get-FileHash -Algorithm MD5 -LiteralPath $_.Path).Hash}}, @{Label='SHA1'; Expression={(Get-FileHash -Algorithm SHA1 -LiteralPath $_.Path).Hash}}, @{Label='SHA256'; Expression={(Get-FileHash -Algorithm SHA256 -LiteralPath $_.Path).Hash}}, @{Label='SignatureStatus'; Expression={(Get-AuthenticodeSignature -LiteralPath $_.Path).Status}}, @{Label='Signature'; Expression={(Get-AuthenticodeSignature -LiteralPath $_.Path).SignerCertificate.Subject.split(',')[0].replace('CN=','').replace('"','')}} 

        # Queries processes only; no hashes, no signature checking
        $processes = Get-CimInstance -Class Win32_Process | Select-Object -Property ParentProcessId, ProcessId, ProcessName, Path, CommandLine, Description, @{Label='CreationDate'; Expression={$_.CreationDate.toString("yyyy-MM-ddTHH:mm:ss.ffffffZ")}}, @{Label='User'; Expression={if ($_.GetOwner().Domain -and $_.GetOwner().User){$_.GetOwner().Domain+"\"+$_.GetOwner().User}}}

        $processes | Export-Csv -NoTypeInformation -Path process_list.csv
        $processes | ConvertTo-Json | Out-File -FilePath process_list.json -Encoding ASCII

    }

}

function Start-PacketCapture
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $install = $false
    )

    # Install, configure, start tshark
    if ( ($config.pcap -eq "true") -and $IsWindows -and $IsVictim ) 
    {
        
        Write-Host "[*] Installing tshark..."

        # Look for already installed tshark
        if ( -not (Find-ProgramFiles 'Wireshark\tshark.exe') ) {

            # Grab tshark
            Write-Host "[*] Downloading wireshark and pcap drivers..."
            if ([Environment]::Is64BitOperatingSystem)
            {
                (New-Object System.Net.WebClient).DownloadFile("https://2.na.dl.wireshark.org/win64/Wireshark-latest-x64.exe", "$pwd\lib\wireshark.exe")
            }
            else 
            {
                (New-Object System.Net.WebClient).DownloadFile("https://2.na.dl.wireshark.org/win32/Wireshark-win32-3.6.19.exe", "$pwd\lib\wireshark.exe")
            }
            Write-Host "[*] Installing wireshark (silent)..."
            Start-Process -FilePath "$pwd\lib\wireshark.exe" -ArgumentList "/S /desktopicon=no /quicklaunchicon=no" -Wait
            # The silent installer WILL NOT install Npcap
            if ($config.pcap_driver -eq "npcap") 
            {
                (New-Object System.Net.WebClient).DownloadFile("https://nmap.org/npcap/dist/npcap-1.60.exe", "$pwd\lib\npcap.exe")
                Write-Host "[*] Installing npcap (interactively) because an OEM license is rediculously overpriced..."
                Start-Process -FilePath "$pwd\lib\npcap.exe" -Wait
            } else {
                (New-Object System.Net.WebClient).DownloadFile("https://www.win10pcap.org/download/Win10Pcap-v10.2-5002.msi", "$pwd\lib\Win10Pcap.msi")
                Write-Host "[*] Installing Win10Pcap..."
                Start-Process -FilePath "$pwd\lib\Win10Pcap.msi" -ArgumentList "ALLUSERS=1 /qn" -Wait
            }

            if ( -not (Find-ProgramFiles 'Wireshark\tshark.exe') )
            {
                Write-Host -ForegroundColor Yellow "[!] Could not find tshark.exe -- please manually install wireshark from wireshark.org"
                throw "Missing tshark"
            }

            # NOTE: tshark.exe -i any    // doesn't work on Windows
            # TODO: make sure npcap installed correctly (otherwise no devices will show up)
            # TODO: run tshark -D and look for Ethernet0
            # TODO: capture wlan?

        }

        if ( -not $install )
        {
            if ($config.pcap_driver -eq "win10pcap")
            {
                # NOTE: Win10Pcap syncs time only on service start. Have to restart here to avoid time sync issues with VMs
                Restart-Service -Name Win10Pcap
            }
            $data = netstat -n | findstr 3389
            $line = $data -replace '^\s+',''
            $line = $line -split '\s+'
            $line = $line[2] -split ':'
            $rdp_ip = $line[0]
            $adapters = ""
            foreach ($i in get-netadapter) {$adapters = $adapters + "-i `"" + $i.Name + "`" "}
            if ( $rdp_ip )
            {
                Write-Output "[*] Filtering out RDP Session"
                Start-Process -WindowStyle hidden -FilePath (Find-ProgramFiles 'Wireshark\tshark.exe') -ArgumentList "$adapters-f `"not host $rdp_ip`" -F pcapng -w `"$pwd\capattack_session.pcapng`"" | Out-Null
            }
            else
            {
                Start-Process -WindowStyle hidden -FilePath (Find-ProgramFiles 'Wireshark\tshark.exe') -ArgumentList "$adapters-F pcapng -w `"$pwd\capattack_session.pcapng`"" | Out-Null
            } 

            Write-Host "[*] Packet capture has started"

        }

    }
    elseif ( ($config.pcap -eq "true") -and $IsLinux -and $IsVictim ) 
    {
        
        # Look for already installed tshark

        if (($PsVersionTable.OS.Contains('Ubuntu')) -or ($PsVersionTable.OS.Contains('Kali'))) {
            if (-not ((Invoke-Expression -Command "apt-get -s install tshark") -clike "* 0 newly installed*")) {    
                # Grab tshark
                Write-Host "[*] Installing tshark..."
                Invoke-Expression -Command "apt-get install debconf-utils -y" | Out-Null
                Invoke-Expression -Command "echo 'wireshark-common wireshark-common/install-setuid boolean true' | debconf-set-selections -v" | Out-Null
                Invoke-Expression -Command "apt-get install tshark -y" | Out-Null
            }
        } else {
            if ((Invoke-Expression -Command "rpm -q wireshark") -clike "* not installed*") {   
                Write-Host "[*] Installing tshark..."
                Invoke-Expression -Command "yum install wireshark -y" | Out-Null
            }
        }
        if ( -not $install )
        {
            $data = Invoke-Expression -Command "netstat -n | grep 3389"
            $line = $data -replace '\s+',' '
            $line = $line -split ' '
            $line = $line[4] -split ':'
            $rdp_ip = $line[0]
            if ( $rdp_ip )
            {
                Write-Output "[*] Filtering out RDP Session"
                Invoke-Expression -Command "touch /tmp/capattack_session.pcapng && chmod +rw /tmp/capattack_session.pcapng"
                # Some versions of linux drop several permissions when capturing and trying to write to certain directories fails. Write to tmp instead.
                Invoke-Expression -Command "nohup tshark -F pcapng -w `"/tmp/capattack_session.pcapng`" `"not host $rdp_ip`" &" | Out-Null
            }
            else
            {
                Invoke-Expression -Command "touch /tmp/capattack_session.pcapng && chmod +rw /tmp/capattack_session.pcapng"
                Invoke-Expression -Command "nohup tshark -F pcapng -w `"/tmp/capattack_session.pcapng`" &" | Out-Null
            } 

            Write-Host "[*] Packet capture has started"
        }

    }
    elseif ($IsMacOS)
    {

        # Unsupported
        Write-Host -ForegroundColor Yellow "[!] Packet capture is not currently supported for MacOS"

    }

}

# NOTE: Clear-EventLog is a built-in function
function Clear-EventLogs
{


    if ($config.clear_event_logs -eq "true")
    {

        # Clear windows event logs
        if ( ($config.log_format -eq "raw") -and $IsWindows -and $IsVictim ) 
        {

            Write-Host "[*] Clearing existing Windows Event Logs..."
            # NOTE: this command will call wevtutil one at a time in series
            # wevtutil el | Foreach-Object {wevtutil cl "$_"} -ErrorAction SilentlyContinue

            # NOTE: this command will call wevtutil in parallel as fast as possible
            # CPU will spike to 100%, but shit will get done
            # The jankiness is so that we're backwards compatable with older PowerShell versions
            # Don't use Start-Job; very heavy and starts another powershell.exe process
            # PowerShell 6+ has Start-ThreadedJob and you can specify -ThrottleLimit
            # PowerShell 7+ has ForEach-Object -Parallel that also runs in a thread, and you can specify a -ThrottleLimit
            # This will literally just bang out 1000+ new process; most should exit rather quickly.
            wevtutil el | Foreach-Object { Start-Process -FilePath wevtutil.exe -ArgumentList "cl ""$_""" -NoNewWindow -RedirectStandardError nul}
            
            # Powershell doesn't properly clear ALL logs so we reverted to wevtutil
            #Powershell method from https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/clear-eventlog?view=powershell-5.1
            # $logs = Get-EventLog -List | ForEach-Object {$_.Log}
            # $logs | ForEach-Object { 
            #    try { 
            #        $logname = $_
            #        Clear-EventLog -LogName $logname 
            #    } 
            #    catch {
            #        Write-Host "[!] Unable to clear $logname"
            #    }
            #}
            # if you wanted to limit it to say, 4 parallel processes, you could do something like this
            <#
            $logsources = wevtutil el
            for ($i = 0 ; $i -le $logsources.Count ; $i = $i + 4) 
            {
                Start-Process -FilePath wevtutil.exe -ArgumentList "cl ""$($logsources[$i])""" -NoNewWindow
                Start-Process -FilePath wevtutil.exe -ArgumentList "cl ""$($logsources[$i+1])""" -NoNewWindow
                Start-Process -FilePath wevtutil.exe -ArgumentList "cl ""$($logsources[$i+2])""" -NoNewWindow
                $proc = Start-Process -FilePath wevtutil.exe -ArgumentList "cl ""$($logsources[$i+3])""" -NoNewWindow -PassThru
                $proc.WaitForExit()
            }
            #>

            <#
            # Variations
            # https://superuser.com/questions/655181/how-to-clear-all-windows-event-log-categories-fast
            Get-EventLog -LogName * ; ForEach { Clear-EventLog $_.Log } 
            
            for /F "tokens=*" %1 in ('wevtutil.exe el') DO wevtutil.exe cl "%1"

            # API calls to OpenEventLogW and ElfClearEventLogFileW
            https://github.com/limbenjamin/Invoke-LogClear/blob/master/Invoke-LogClear.ps1

            # Note: calling the ASCII and Wide version of the API will CRASH Event Logging
            # https://github.com/slyd0g/SharpCrashEventLog

            #>

            Write-Host "[*] Windows Event Logs have been cleared"

        }
        elseif ($IsLinux -and $IsVictim)
        {

            $logstoclear = @('/var/log/syslog','/var/log/auth.log','/var/log/secure','/var/log/kern.log',
                             '/var/log/tomcat*/*access*txt','/var/log/tomcat*/*localhost.*log',
                             '/var/log/nginx*/*access*log','/var/log/nginx*/*error*log','/var/log/httpd*/*access*log',
                             '/var/log/httpd*/*error*log','/var/log/apache*/*access*log','/var/log/apache*/*error*log',
                             '/var/log/audit/audit.log','/var/log/messages')
            
            ForEach ($log in $logstoclear) {
                if (Test-Path $log){
                    try {
                        Invoke-Expression -Command "cat /dev/null > $log"
                    } catch { continue }
                }
            }
            Write-Host "[*] Linux Event Logs have been cleared"

        }
        elseif ($IsMacOS -and $IsVictim)
        {

            # Unsupported
            Write-Host -ForegroundColor Yellow "[!] Clearing event logs is not currently supported for MacOS"

        }

    }

}

function Start-Session
{

    $StartTime = (Get-Date).ToUniversalTime().tostring("yyyy-MM-ddTHH:mm:ss.ffffffZ")
    $HostName = [System.Net.Dns]::GetHostName()

    $session = New-Object PsObject
    $session | Add-Member -MemberType NoteProperty -Name 'session_id' -Value ''
    $session | Add-Member -MemberType NoteProperty -Name 'start_time' -Value $StartTime
    $session | Add-Member -MemberType NoteProperty -Name 'end_time' -Value ''

    $hosts = New-Object PsObject
    $hosts | Add-Member -MemberType NoteProperty -Name 'start_time' -Value ''
    $hosts | Add-Member -MemberType NoteProperty -Name 'end_time' -Value ''
    $hosts | Add-Member -MemberType NoteProperty -Name 'host_name' -Value $HostName
    $hosts | Add-Member -MemberType NoteProperty -Name 'host_key' -Value ''
    $hosts | Add-Member -MemberType NoteProperty -Name 'machine_type' -Value $config.machine_type
    if ($IsWindows)
    {
        $hosts | Add-Member -MemberType NoteProperty -Name 'os_type' -Value 'windows'
        $hosts | Add-Member -MemberType NoteProperty -Name 'os_version' -Value $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
        if ($config.display_name)
        {
            $hosts | Add-Member -MemberType NoteProperty -Name 'display_name' -Value $config.display_name
        }
        else 
        {
            $hosts | Add-Member -MemberType NoteProperty -Name 'display_name' -Value "Windows"
        }
    }
    elseif ($IsLinux)
    {
        $hosts | Add-Member -MemberType NoteProperty -Name 'os_type' -Value 'linux'
        $hosts | Add-Member -MemberType NoteProperty -Name 'os_version' -Value $PsVersionTable.OS
        if ($config.display_name)
        {
            $hosts | Add-Member -MemberType NoteProperty -Name 'display_name' -Value $config.display_name
        }
        else 
        {
            $hosts | Add-Member -MemberType NoteProperty -Name 'display_name' -Value "Linux"
        }
    }
    elseif ($IsMacOS)
    {
        $hosts | Add-Member -MemberType NoteProperty -Name 'os_type' -Value 'macos'
        $hosts | Add-Member -MemberType NoteProperty -Name 'os_version' -Value $PsVersionTable.OS
        if ($config.display_name)
        {
            $hosts | Add-Member -MemberType NoteProperty -Name 'display_name' -Value $config.display_name
        }
        else 
        {
            $hosts | Add-Member -MemberType NoteProperty -Name 'display_name' -Value "MacOS"
        }
    }
    $session | Add-Member -MemberType NoteProperty -Name 'hosts' -Value $hosts

    ConvertTo-Json $session | Out-File -FilePath .activesession -Encoding ASCII

    # Notify the user
    Write-Host -ForegroundColor Green "[*] Session has started - fire away!"

}

function Set-Xauth
{
    if ($IsLinux){
        # This fixes xauth issues on kali and lets the command actually run on Ubuntu
        Invoke-Expression -Command "sudo -u $sudoer xhost +local: >/dev/null 2>&1"
    }
}

