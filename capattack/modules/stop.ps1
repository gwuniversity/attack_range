
function Capattack-Stop {
    Stop-Capattack @args
}

function Stop-Capattack
{

    Param (
        [Parameter(Position=0, Mandatory=$false)]
        [bool]
        $force = $false,

        [Parameter(Mandatory=$false)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [Switch]
        $Headless
    )

    Push-Location
    Set-Location (Split-Path (Get-Module capattack).Path -Parent)

    try {
        Start-Transcript -Path "$pwd\debug.log" -IncludeInvocationHeader -Append -ErrorAction Stop| Out-Null
    } catch {
        # Method to properly start the transcript if something didn't shut down correctly
        # https://stackoverflow.com/questions/46692735/powershell-transcript-errors-when-transcript-is-already-running
        Start-Transcript -Path "$pwd\debug.log" -IncludeInvocationHeader -Append | Out-Null
    }

    Parse-Configuration
    if ($config.headless.ToLower() -ne "false"){
        $Headless = $true
    }

    # Check if session is recording
    if ( -not (Test-Path .activesession -PathType Leaf) ) 
    {
        Write-Host -ForegroundColor Yellow "[!] Error: there is no active session in progress"

        # Ask the user if they want to forcefully remove
        if ( -not ($force) )
        {
            if ($Headless) {
                $confirmation = "y"
            } else {
                $confirmation = Read-Host "Do you want to forcefully clear anything from an improperly saved session? y/N"
            }
            if ( ($confirmation.ToLower().Trim() -eq 'y') -or ($confirmation.ToLower().Trim() -eq 'yes' ) ) 
            {
                $force = $true
            }
            else 
            {
                return
            }

        }

    }

    IsCapAttackInstalled

    if ($force)
    {
        # Note: we're going to turn off errors and just power through them
        $ErrorActionPreference = "SilentlyContinue"
    } else {
        Stop-Session
    }

    Stop-DesktopCapture $force

    Stop-Keylogger $force

    Stop-PacketCapture $force

    Stop-EDR

    if ( -not ($installed) )
    {

        Stop-Auditpol

        Stop-PSLogging

    }

    if ( -not ($force) ) 
    {
        Export-EventLogs
    }

    if ( -not ($installed) )
    {

        Restore-Time

    }

    if ($force)
    {

        # Clean up process list
        Remove-Item -Path process_list.csv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path process_list.json -Force -ErrorAction SilentlyContinue

        # Clean up SystemInfo
        Remove-Item -Path systeminfo.txt -Force -ErrorAction SilentlyContinue

        # Remove active session
        Remove-Item -Path .activesession -Force -ErrorAction SilentlyContinue

        # Stop ignoring all errors
        $ErrorActionPreference = "Continue"

        Write-Host -ForegroundColor Green "[*] Session junk has been cleaned up!"

    }
    else 
    {
        Save-Session
    }

    Stop-Transcript | Out-Null
    
    Pop-Location
    
}

function Stop-Keylogger
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $force = $false
    )    

    if ( ($config.keystrokes -eq "true") -or $force )
    {

        if ($IsWindows)
        {
            Write-Host "[*] Stopping keylogger..."

            $null = Stop-Process -Name keylogger -Force -ErrorAction SilentlyContinue
        }
        elseif ($IsLinux)
        {
            Write-Host "[*] Stopping keylogger..."

            $null = Stop-Process -Name keylogger -Force -ErrorAction SilentlyContinue
        }
        elseif ($IsMacOS)
        {
            # Unsupported
            Write-Host -ForegroundColor Yellow "[!] Keystroke logging is not currently supported for MacOS"
        }

    }

    if ($force)
    {
        # Delete any old keystrokes files
        Remove-Item -Path keystrokes.log -Force -ErrorAction SilentlyContinue | Out-Null
    }

}

function Stop-DesktopCapture
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $force = $false
    )    

    if ( ($config.desktop -eq "true") -or $force )
    {

        if ($IsWindows)
        {
            <#
            ffmpeg will exit gracefully if you send 'q' to STDIN, or the 'CTRL+C' or 'CTRL+BREAK' signals
            (See https://trac.ffmpeg.org/ticket/6336)

            If we won't gracefully exit and are using an mp4 container, the moov atom (video headers) do not get written
            as they are at the END of the file.  This results in a corrupted video.

            Sending signals on Windows is WEIRD.

            There are some third-party binaries that do this:
            - https://github.com/alirdn/windows-kill (we're using this one, but doesn't always work - see https://github.com/alirdn/windows-kill/issues/9)
            - https://github.com/kettek/wprocsend

            You can use Win32 APIs to send it programmatically.  It roughly works like:
            FreeConsole()
            AttachConsole()
            GenerateConsoleCtrlEvent(0, pid);
            FreeConsole()
            AttachConsole()

            For GenerateConsoleCtrlEvent() to work, you have to be attached to the console of the PID (well, technically process group, 
            but they're the same) your trying to kill.

            You can also only ever be attached to one console, which is why you must call FreeConsole() first.

            In reality, it never get past the first call to FreeConsole() because we're running from a console app, and when you call FreeConsole()
            Windows cleans up the process.

            Attempted a myriad of trickery to run the PowerShell code in a way that won't kill our own console, but the best option seems to use
            a GUI app that does not depend on a console for its existance.

            PowerShell Examples:
            - https://stackoverflow.com/questions/813086/can-i-send-a-ctrl-c-sigint-to-an-application-on-windows
            - https://github.com/Delapro/DelaproInstall/blob/627ffe705b75774f7915ef3353d70774bc48fa5b/DLPInstall.PS1
            - https://github.com/ptytb/pips/blob/48c56f332eef1b28faea0da7b43e28801d2c0b01/pips.psm1#L376-L431
            - https://github.com/VISSLM/CASSANDRA/blob/cd9fd9e83f507e2bab5075399d812e3fb4368920/bin/stop-server.ps1#L62-L161
            - https://github.com/matiasnaess/Valheim-Server-Autoupdater/blob/b9ab2ce7dd9471712f1fd74cc5e3ade98f5f3362/Valheim-updater.ps1#L27-L43

            2024 June Update:
            We're now using ffmpeg_wrapper on windows (https://github.com/RattleyCooper/ffmpeg_wrapper/tree/b8257e68e03809442a15dbd38b1a8d3751bd0b6f)
            This allows for cleaner shutdown using regular taskkill using an outer wrap program that cleanly handles taskkill
            #>

            Write-Host "[*] Stopping desktop capture..."
            $process = Get-Process -Name ffmpeg -ErrorAction SilentlyContinue
            if ($process.Count -ne 0) 
            {
                
                $i = 0
                do
                {
                    Start-Process -windowstyle hidden -FilePath "taskkill.exe" -Argument "/im ffmpeg_wrap.exe"
                    $i++
                    Start-Sleep 1
                    
                } until ( ($i -eq 3) -or (-not (IsFfmpegRunning) ))

            }
            # If that still failed, forcefully exit
            if (IsFfmpegRunning)
            {
                # If we get here, things are pretty dire.  Our video will be corrupted when we kill ffmpeg.
                Write-Host -ForegroundColor Yellow "[!] Forcefully stopping ffmpeg..."

                do 
                {

                    Start-Process -windowstyle hidden -FilePath "taskkill.exe" -Argument "/im ffmpeg.exe /f"
                    Start-Sleep 1
    
                } until (-not (IsFfmpegRunning))

            }
    
            if ($force)
            {
                do 
                {
    
                    $null = Remove-Item -Path "capattack_session.mkv" -Force -ErrorAction SilentlyContinue
                    Start-Sleep 1
    
                } until (-not (Test-Path "capattack_session.mkv" -PathType Leaf))
            }

            if ($config.ffmpeg_recorder -eq "dshow") 
            {

                # Unregister DLLs
                $dlls = (Get-ChildItem -path .\lib -include '*.dll' -recurse).fullname
                foreach ($dll in $dlls) 
                {
                    Start-Process -WindowStyle hidden -FilePath regsvr32 -ArgumentList "/s /u $dll" -Wait 
                }

            } 
            else # gdigrab
            {

                # Turn Secure Desktop back on
                New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value "1" -PropertyType "DWORD" -force | Out-Null

            }

            Write-Output "[*] Desktop capture stopped. Creating video file."  
            
            Start-ProcessEnhanced -FilePath .\lib\ffmpeg.exe -Arguments "-y -i capattack_session.mkv -filter:v fps=25 capattack_session.mp4" | Out-Null

        }
        elseif ($IsLinux)
        {

            Write-Host "[*] Stopping desktop capture..."

            # Look for already installed ffmpeg
            if ( -not (which ffmpeg) ) 
            {
                Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg"
                throw "Missing ffmpeg"
            }
            else
            {
                
                # Send sigint to ffmpeg
                if (which killall) 
                {
                    killall -s SIGINT ffmpeg >/dev/null 2>&1
                }
                elseif (which pkill)
                {
                    pkill -SIGINT ffmpeg >/dev/null 2>&1
                }
                else
                {
                    kill -2 $(pgrep ffmpeg)
                }

                # Now we'll wait for a bit while ffmpeg writes the buffer to disk and finalizes the file
                $i = 0
                do
                {
                    $i++
                    Start-Sleep 1
                } until ( ($i -eq 15) -or ( (-not (IsFfmpegRunning)) -and (-not (IsFileLocked("capattack_session.mkv"))) ) )

            }

            Write-Output "[*] Desktop capture stopped. Creating MP4."
            Invoke-Expression -Command "ffmpeg -hide_banner -loglevel error -y -i capattack_session.mkv -filter:v fps=25 capattack_session.mp4"

        }
        elseif ($IsMacOS)
        {

            Write-Host "[*] Stopping desktop capture..."

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
                Write-Host -ForegroundColor Yellow "[!] Could not find ffmpeg"
                throw "Missing ffmpeg"
            }
            else 
            {
                
                # Send sigint to ffmpeg
                # NOTE: it won't find 'ffmpeg' alone; not sure why it needs a / but that might not work for all launch variations
                # NOTE: ffmpeg doesn't seem to respond to SIGINT like it should.
                pkill -2 -f '/ffmpeg'
                # Could try other commands like:
                # killall -SIGINT ffmpeg

                # Now we'll wait for a bit while ffmpeg writes the buffer to disk and finalizes the file
                $i = 0
                do
                {
                    $i++
                    Start-Sleep 1
                } until ( ($i -eq 15) -or ( (-not (IsFfmpegRunning)) -and (-not (IsFileLocked("capattack_session.mkv"))) ) )

            }

            Write-Output "[*] Desktop capture stopped. Creating MP4."
            Invoke-Expression -Command "$ffmpeg_path -y -i capattack_session.mkv -filter:v fps=25 capattack_session.mp4"

        }

    }

}

function Stop-PacketCapture
{

    Param (
        [Parameter(Mandatory=$false)]
        [bool]
        $force = $false
    )    

    if ( ($config.pcap -eq "true") -or $force )
    {

        if ($IsWindows)
        {
            Write-Host "[*] Stopping tshark.exe..."

            # Send Ctrl + C
            $process = Get-Process -Name tshark -ErrorAction SilentlyContinue
            if ($process.Count -ne 0) 
            {
                
                $i = 0
                do
                {
                    $p = Start-ProcessEnhanced -FilePath "taskkill.exe" -Arguments "/im tshark.exe"
                    $i++
                    Start-Sleep 1
                    
                } until ( ($i -eq 15) -or ($p.ExitCode -eq 0) )

            }
        }
        elseif ($IsLinux)
        {
           
            Write-Host "[*] Stopping tshark"

            # Send Ctrl + C
            $process = Get-Process -Name tshark -ErrorAction SilentlyContinue
            if ($process.Count -ne 0) 
            {
                
                $i = 0
                do
                {
                    Invoke-Expression -Command "killall tshark 2>/dev/null"
                    $i++
                    Start-Sleep 1
                    $pcount = Invoke-Expression -Command "ps aux | grep tshark | wc -l"
                    
                } until ( ($i -eq 15) -or ($pcount -eq 1) )
                Copy-Item "/tmp/capattack_session.pcapng" -Destination "$pwd/capattack_session.pcapng"
            }
        }
        elseif ($IsMacOS)
        {
            # Unsupported
            Write-Host -ForegroundColor Yellow "[!] Packet capture is not currently supported for MacOS"
        }

    }

    if ($force)
    {
        # Delete any old pcapng files
        Remove-Item -Path capattack_session.pcapng -Force -ErrorAction SilentlyContinue | Out-Null
    }

}
function Stop-EDR
{

    # Turn off sysmon logging sysmon
    # If we uninstall sysmon completely, it also removes the logs we just captured
    # So we'll just instruct sysmon to not log anything while we clean up the session
    if ( ($config.edr -eq "sysmon") -and $IsWindows -and $IsVictim ) 
    {

        Write-Host "[*] Stopping sysmon logging..."

        # Note: we install from $PWD, but sysmon copies the driver to system32
        # So to uninstall, we need to reference that one, not the local one
        if ([Environment]::Is64BitOperatingSystem) 
        {
            $sysmon_path = $Env:WinDir + "\sysmon64.exe"
        } 
        else 
        {
            $sysmon_path = $Env:WinDir + "\sysmon.exe"
        }

        # Load the config that doesn't log anything
        $process = Start-ProcessEnhanced -FilePath $sysmon_path -Arguments "-c $pwd\sysmon_off.xml"
        <#
        $process = Start-Process -NoNewWindow -FilePath $sysmon_path -ArgumentList "-c sysmon_off.xml" -PassThru -Wait -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
        Remove-Item -Path stdout.txt -Force
        Remove-Item -Path stderr.txt -Force
        #>

        # TODO: better error handling if sysmon fails to stop
        if ($process.ExitCode -ne 0) 
        {
            Write-Host -ForegroundColor Yellow "[!] Failed to turn off sysmon. Please review the sysmon_off.xml configuration file."
            throw "Sysmon configuration error"
        }

    }
    elseif (($config.edr -eq "sysmon") -and $IsLinux -and $IsVictim )
    {
        # Unsupported
        $process = Invoke-Expression -Command "sysmon -c $pwd/sysmon_off.xml"
        if (-Not $process.Contains("Configuration file validated."))
        {
            Write-Host -ForegroundColor Yellow "[!] Failed to turn off sysmon. Please review the sysmon_off.xml configuration file."
            throw "Sysmon configuration error"
        }
    }
    elseif (($config.edr -ne "sysmon") -and $IsLinux)
    {
        Write-Host -ForegroundColor Yellow "[!] Only Sysmon supported for Linux"
    }
    elseif ($IsMacOS)
    {
        # Unsupported
        Write-Host -ForegroundColor Yellow "[!] No EDR is currently supported for MacOS"
    }
    
}

# NOTE: this function is no longer called
# We keep sysmon installed but with a configuration that logs nothing
function Uninstall-EDR
{

    if ( ($config.edr -eq "sysmon") -and $IsWindows -and $IsVictim ) 
    {

        Write-Host "[*] Uninstalling sysmon..."

        # Note: the event logs disappear when sysmon is uninstalled
        # So we have to export first before we uninstall it completely

        # Note: we install from PWD, but sysmon copies the driver to system32
        # So to uninstall, we need to reference that one, not the local one
        if ([Environment]::Is64BitOperatingSystem)
        {
            $sysmon_path = $Env:WinDir + "\sysmon64.exe"
        } 
        else
        {
            $sysmon_path = $Env:WinDir + "\sysmon.exe"
        }

        $process = Start-ProcessEnhanced -FilePath $sysmon_path -Arguments "-u"
        <#
        $process = Start-Process -NoNewWindow -FilePath $sysmon_path -ArgumentList "-u" -PassThru -Wait  -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
        Remove-Item -Path stdout.txt -Force
        Remove-Item -Path stderr.txt -Force
        #>

        # TODO: better error handling if sysmon fails to uninstall
        if ($process.ExitCode -ne 0) 
        {
            Write-Host -ForegroundColor Yellow "[!] Sysmon failed to uninstall. Please clean it up manually"

        }
    }
    elseif ($IsLinux)
    {
        # Unsupported
        Write-Host -ForegroundColor Yellow "[!] No EDR is currently supported for Linux"
    }
    elseif ($IsMacOS)
    {
        # Unsupported
        Write-Host -ForegroundColor Yellow "[!] No EDR is currently supported for MacOS"
    }

}

function Stop-Auditpol
{  

    if (($config.auditpol -eq "true") -and $IsWindows -and $IsVictim)
    {

        Write-Host "[*] Restoring auditpol to previous configuration..."

        # Restore from their previous config
        $process = Start-ProcessEnhanced -FilePath auditpol.exe -Arguments "/restore /file:$pwd\auditpol_backup.csv"
        <#
        $process = Start-Process -NoNewWindow -FilePath auditpol.exe -ArgumentList "/restore /file:$pwd\auditpol_backup.csv" -PassThru -Wait -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
        Remove-Item -Path stdout.txt -Force
        Remove-Item -Path stderr.txt -Force
        #>
        Remove-Item -Path auditpol_backup.csv -ErrorAction SilentlyContinue
        # TODO: better error handling 
        if ($process.ExitCode -ne 0) 
        {
            Write-Host -ForegroundColor Yellow "[!] Failed to restore auditpol to previous configuration"
        }

        Write-Host "[*] Auditpol configuration restored"

    }

}

function Stop-PSLogging
{

    if (($config.powershell_module_scriptblock -eq "true") -and $IsWindows -and $IsVictim)
    {

        Write-Host "[*] Stopping powershell module and script block logging..."

        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 0 -PropertyType "DWORD" -force
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockInvocationLogging" -Value 0 -PropertyType "DWORD" -force
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableScriptBlockLogging" -Value -0 -PropertyType "DWORD" -force

        Write-Host "[*] Stopped powershell module and script block logging"

    }

}

function Export-EventLogs
{
  
    if ($IsWindows -and $IsVictim)
    {

        if ($config.log_format -eq "raw") 
        {

            Write-Host "[*] Copying existing raw Windows Event Logs (.evtx)..."

            # Create Logs Folder
            New-Item -Path $Guid -Name "logs" -ItemType "directory" | Out-Null
           
            if ( [Environment]::Is64BitProcess){
                $evtx = [System.Environment]::SystemDirectory + "\Winevt\Logs\"
            } else {
                $evtx = $env:WinDir + "\SysNative\Winevt\Logs\"
            }
            
            if (Test-Path $evtx) {
                Copy-Item $evtx* $Guid\logs -Recurse -Force
            } else{
                Write-Host -ForegroundColor Yellow  "[!] Error: Unable to move existing Windows Event Logs (.evtx)"
            }

            <#
            There are two built-in ways to get Events in PowerShell: Get-EventLog and Get-WinEvent
            tl;dr - Get-EventLog is the older version.  Use Get-WinEvent
            Read more at: https://evotec.xyz/powershell-everything-you-wanted-to-know-about-event-logs

            PowerShell does not limit the amount of logs you can request. 
            However, the Get-WinEvent cmdlet queries the Windows API which has a limit of 256. 
            This can make it difficult to filter through all of your logs at one time. 
            You can work around this by using a foreach loop to iterate through each log like this: 
            Get-WinEvent -ListLog * | ForEach-Object{ Get-WinEvent -LogName $_.Logname }

            As a quirk, LogName cannot be used as a param with FilterHashtable; it needs to be included as a filter, e.g.
            $filter = @{
                LogName= $_.Logname
                StartTime=$(Get-Date -Date $session.start_time)
                EndTime=$(Get-Date -Date $session.end_time)
            }

            Windows Events are stored as Binary XML. Attributes and nesting doesn't output well as JSON.
            Some values get returned as Objects -- e.g., "TimeCreated":  "\/Date(1617894481236)\/",
            e.g., -- Get-WinEvent -LogName "Security" -MaxEvents 1 | ConvertTo-Json

            https://github.com/counteractive/Get-EnhancedWinEvent looked promising, but they don't handle
            common edge cases or maintain the tool

            There are other tools that can export Windows Events.  They work with mixed success.

            https://github.com/omerbenamram/evtx
            This tool is fast. I like event logs in order (so does splunk) so much of the multi-threading speedups get lost (set threads to 1)
            The output format is not easily controllable - it's JSON but has non-JSON "Event #123" between each record that would need to be cleaned up. 
            JSON parsed events look beautiful when they worked, though not all log sources came out cleanly.
            There are python wrappers for it, but that doesn't help us here.

            https://github.com/0xrawsec/golang-evtx
            Looks interesting; didn't test

            https://github.com/vavarachen/evtx2json
            Didn't test.  it's python and widely used by SANS

            https://github.com/OTRF/mordor/blob/master/scripts/data-collectors/Mordor-WinEvents.ps1
            I really like the format.  Mordor datasets are one JSON array per line.  Seems to parse well.
            Roberto is super active in the community, so if I were to bet on a horse, it'd be this one.
            Though omerbenamram's evtx seems to be a bit more widely used. 
            #>
            $StartTime = $(Get-Date -Date $session.start_time).ToUniversalTime()
            $EndTime = $(Get-Date).ToUniversalTime()

            # Create Logs Folder
            New-Item -Path $Guid -Name "xml_logs" -ItemType "directory" | Out-Null

            $logs = Get-WinEvent -ListLog *
            for ($counter=0; $counter -lt $logs.Length; $counter++)
            {
                $PercentComplete = [Math]::Round(($counter / $logs.Length) * 100)
                Write-Progress -Activity "Exporting event logs ($PercentComplete% complete)" -Status "Current log: $($logs[$counter].LogName)" -PercentComplete $PercentComplete;

                # Calculate the output filename for this log
                $OutFile = $(Join-Path -Path $Guid\xml_logs -ChildPath $logs[$counter].LogName.replace(" ", "_").replace("/","--"))

                try 
                {
                    # Try blocks catch only terminating errors, so force it to stop on any error

                    <#
                    READ THIS BEFORE YOU CHANGE ANY CODE
                    1) Originally, we took the output of Get-WinEvent, stored it in an $events variable, then looped over reach item.
                    THIS WAS BAD because it would take 1000s of events and store them in a variable in memory.  I saw powershell.exe
                    ballon to over 1.7 GB at points.  No bueno.

                    2) PowerShell is neat in that they have pipelines... which are a series of commands connected by pipeline operators (|).
                    Each pipeline operator sends the results of the preceding command to the next command. The result is a complex command 
                    chain or pipeline that is composed of a series of simple commands
                    .
                    WE SHOULD DO THIS PROCESSING AS A PIPELINE.  Instead of waiting to get all of the events, we can start acting upon 
                    a single event as we receive it.

                    We should investigate how the Out-File performs in the ForEach-Object vs. the next step in the pipeline.
                    Inside the ForEach-Object will cause it to open the file, write the data, and close the file for every single event.
                    As the next step in the pipeline, it theoretically should wait until all of procesing is done and write the data once.
                    This could have memory implications (that processed data has to be stored somewhere) or failure implications (what if
                    an error happens and logs don't get written).

                    If you run this command for testing, you'll see however that the test.log is constantly growing as ForEach finishes an object.

                    Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-Sysmon/Operational" } -Oldest -ErrorAction Stop | ForEach-Object { $_.ToXML() } | Out-File -Append .\test.log
                    #>

                    Get-WinEvent -FilterHashtable @{LogName=$logs[$counter].LogName; StartTime=$StartTime; EndTime=$EndTime } -Oldest -ErrorAction Stop | ForEach-Object {
                        # ToXML returns an XML string; actually convert it to an XML DOM we can manipulate
                        $singleEvent = [xml] $_.ToXml()
                        $event_hash = SHA256($singleEvent.OuterXml)
                        
                        # add row_id based on sha256 of the XML log
                        $row_id = $singleEvent.Event.PrependChild($singleEvent.CreateElement("row_id", $singleEvent.Event.NamespaceURI))
                        $row_id.AppendChild($singleEvent.CreateTextNode($event_hash)) | Out-Null

                        # add session_id GUID; may collide with existing session so we should deconflict server side
                        $session_id = $singleEvent.Event.PrependChild($singleEvent.CreateElement("session_id", $singleEvent.Event.NamespaceURI))
                        $session_id.AppendChild($singleEvent.CreateTextNode($Guid)) | Out-Null

                        # convert back to a string and change the literal newlines to representation of newlines
                        $singleEvent.OuterXml.Replace("`r","\r").Replace("`n","\n") 
                    } | Out-File -Append -Encoding ASCII -FilePath $OutFile

                } 
                catch [Exception] 
                {
                    if ($_.Exception -match "No events were found that match the specified selection criteria") 
                    {
                        # do nothing, it just means no events were found in this log
                    } 
                    elseif ($_.Exception -match "The pipeline has been stopped") 
                    {
                        # event log is just empty
                    } 
                    elseif ($_.Exception -match "hexadecimal value")
                    {
                        # Cannot convert value "<Event>...</Event>" to type
                        # "System.Xml.XmlDocument". Error: "'♣', hexadecimal value 0x05, is an invalid character.

                        # TODO: See the accepted answer here if we need to skip processing the data element
                        # Some sysmon events (EventID=15) sometimes contain binary data.

                        # https://social.technet.microsoft.com/Forums/windows/en-US/98fc0b6c-863c-45fb-938a-81dcc94b3759/hexadecimal-value-0x05-is-an-invalid-character-on-eventlog-item?forum=winserverpowershell
                    }
                    else 
                    {
                        # Some other error happened so rethrow it so the user will see it
                        throw $_
                    }
                }

            }

            # Delete empty files
            Get-ChildItem $Guid | Where-Object {$_.length -eq 0} | Remove-Item -Force
        } 
        else 
        {

            # Unsupported
            Write-Host -ForegroundColor Yellow "[!] Unsupported log_format: " + $config.log_format

        }
        
    }
    elseif ($IsLinux -and $IsVictim)
    {
        Write-Host "[*] Exporting event logs... this could take a moment"
        # Create Logs Folder
        New-Item -Path $Guid -Name "logs" -ItemType "directory" | Out-Null
        # Sysmon
        if ($PSVersionTable.OS.Contains('Ubuntu')) {
            if (($PSVersionTable.PSVersion.Major -eq 7) -And ($PSVersionTable.PSVersion.Minor -lt 3)) {
                Export-LinuxLog -FilePath "/var/log/syslog" -ExportName "Sysmon.linux" -ExtraFormatting "| grep 'Linux-Sysmon' |  grep '<Event>' | awk '{split(`$0,a,\`"sysmon: \`"); print a[2]}'" 
            } else {
                Export-LinuxLog -FilePath "/var/log/syslog" -ExportName "Sysmon.linux" -ExtraFormatting "| grep 'Linux-Sysmon' |  grep '<Event>' | awk '{split(`$0,a,`"sysmon: `"); print a[2]}'"
            }
        } else {
            if (($PSVersionTable.PSVersion.Major -eq 7) -And ($PSVersionTable.PSVersion.Minor -lt 3)) {
                Export-LinuxLog -FilePath "/var/log/messages" -ExportName "Sysmon.linux" -ExtraFormatting "| grep 'Linux-Sysmon' |  grep '<Event>' | awk '{split(`$0,a,\`": \`"); print a[2]}'" 
            } else {
                Export-LinuxLog -FilePath "/var/log/messages" -ExportName "Sysmon.linux" -ExtraFormatting "| grep 'Linux-Sysmon' |  grep '<Event>' | awk '{split(`$0,a,`": `"); print a[2]}'"
            }
        }
        
        # auth.log
        Export-LinuxLog -FilePath "/var/log/auth.log" -ExportName "auth.log"
        # secure
        Export-LinuxLog -FilePath "/var/log/secure" -ExportName "secure"
        # kern log
        Export-LinuxLog -FilePath "/var/log/kern.log" -ExportName "kern.log"
        # syslog
        Export-LinuxLog -FilePath "/var/log/syslog" -ExportName "syslog" -ExtraFormatting "| grep -v 'Linux-Sysmon'"
        # web logs if available
        # tomcat
        If (Test-Path -Path '/var/log/tomcat*') { 
            Export-LinuxLog -FilePath "/var/log/tomcat*/*access*txt" -ExportName "tomcat_access.log" -DategrepFormat "apache"
            Export-LinuxLog -FilePath "/var/log/tomcat*/*localhost.*log" -ExportName "tomcat.log"
        }
        # nginx
        If (Test-Path -Path '/var/log/nginx/') { 
            Export-LinuxLog -FilePath "/var/log/nginx*/*access*log" -ExportName "nginx_access.log" -DategrepFormat "apache"
            Export-LinuxLog -FilePath "/var/log/nginx*/*error*log" -ExportName "nginx_error.log" -DategrepFormat "apache"
        }
        # apache rhel
        If (Test-Path -Path '/var/log/httpd/') { 
            Export-LinuxLog -FilePath "/var/log/httpd*/*access*log" -ExportName "apache_access.log" -DategrepFormat "apache"
            Export-LinuxLog -FilePath "/var/log/httpd*/*error*log" -ExportName "apache_error.log" -DategrepFormat "apache"
        }
        # apache debian
        If (Test-Path -Path '/var/log/apache2/') { 
            Export-LinuxLog -FilePath "/var/log/apache*/*access*log" -ExportName "apache_access.log" -DategrepFormat "apache"
            Export-LinuxLog -FilePath "/var/log/apache*/*error*log" -ExportName "apache_error.log" -DategrepFormat "apache"
        }

        # Create auditd logs
        Write-Host "[*] Exporting auditd logs..."
        if (ausearch -ts (Get-Date).tostring('MM/dd/yy') 2>`&1) {
            $StartTime = (Get-Date -Date $session.start_time).ToUniversalTime().tostring('MM/dd/yy HH:mm:ss')
            $EndTime = (Get-Date -Date $session.end_time).ToUniversalTime().tostring('MM/dd/yy HH:mm:ss')
        } else {
            $StartTime = (Get-Date -Date $session.start_time).ToUniversalTime().tostring('MM/dd/yyyy HH:mm:ss')
            $EndTime = (Get-Date -Date $session.end_time).ToUniversalTime().tostring('MM/dd/yyyy HH:mm:ss')
        }
        $OutFile = $(Join-Path -Path $Guid/logs -ChildPath "Auditd.linux")
        try{
            $process = Invoke-Expression -Command "ausearch -ts $StartTime -te $EndTime | grep 'type='"
        } catch {
            Write-Host -ForegroundColor Yellow "[!] Failed to export auditd logs."
        }
        $process | Out-File -Append -Encoding ASCII -FilePath $OutFile
    }
    elseif ($IsMacOS -and $IsVictim)
    {
        # Unsupported
        Write-Host -ForegroundColor Yellow "[!] Event logs are not currently supported for MacOS"
    }

}

function Stop-Session 
{

    # Record the endtime BEFORE we start tearing things down, which will generate logs
    $EndTime = (Get-Date).ToUniversalTime().tostring("yyyy-MM-ddTHH:mm:ss.ffffffZ")

    $script:Guid = New-Guid

    # Create Session Folder
    Write-Host "[*] Created session folder '$Guid'"
    New-Item -Path "." -Name $Guid -ItemType "directory" | Out-Null

    # Get Metadata
    $script:session = Get-Content .activesession | ConvertFrom-Json
    $session.session_id = $Guid
    $session.end_time = $EndTime

}


function Save-Session {

    if ($IsWindows)
    {
        $HostName = [System.Net.Dns]::GetHostName()
    }
    else 
    {
        $HostName = $(hostname)
    }

    # NOTE: some of these actions could fail if a setting were disabled
    # Would be good to check if the file exists or the config was enabled first

    # Package Keystrokes 
    if ($config.keystrokes -eq "true")
    {
        Move-Item -Path keystrokes.log -Destination $(Join-Path -Path ".\$Guid" -ChildPath "$HostName.keystrokes.log") -ErrorAction SilentlyContinue
    }

    # Package Video
    # TODO: compress if saved losslessly

    if ($config.desktop -eq "true")
    {
        try {
                
            if ($IsLinux)
            {
                # On Kali, CreationTime returns the incorrect timestamp, so we'll use stat or ls
                # NOTE: only works on ext4; other file systems don't record the creation timestamp
                # https://unix.stackexchange.com/questions/50177/birth-is-empty-on-ext4/131347#131347

                # NOTE: ls -l may return a different number of spaces on different OSs; don't use with cut/awk
                # ls -l --time=birth --time-style=full-iso <filename>

                # NOTE: stat won't return the birth (crtime) before kernel 4.11 / coreutils 8.31 / glibc 2.28
                # stat -c%w <filename>
                $VideoStartTime = (Get-Date (/bin/bash ./lib/xstat capattack_session.mkv | grep "Birth" | cut -d " " -f3-5)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
                $VideoEndTime = (Get-Item capattack_session.mkv).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
            }
            else 
            {
                $VideoStartTime = (Get-Item capattack_session.mkv).CreationTime.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
                $VideoEndTime = (Get-Item capattack_session.mkv).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
            }
            Move-Item -Path capattack_session.mp4 -Destination $(Join-Path -Path ".\$Guid" -ChildPath "$HostName.mp4") -ErrorAction SilentlyContinue
            Remove-Item -Path capattack_session.mkv -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host -ForegroundColor Yellow "[!] Video capture error. Saving capture without video."
            $VideoStartTime = $session.start_time
            $VideoEndTime = $session.end_time
        }
    }

    # Package PCAP
    if ($config.pcap -eq "true")
    {
        Move-Item -Path capattack_session.pcapng -Destination $(Join-Path -Path ".\$Guid" -ChildPath "$HostName.pcapng") -ErrorAction SilentlyContinue
    }

    # Move SystemInfo
    Move-Item -Path systeminfo.txt -Destination $(Join-Path -Path ".\$Guid" -ChildPath "systeminfo.txt") -ErrorAction SilentlyContinue

    # Move Process Lists
    Move-Item -Path process_list.csv -Destination $(Join-Path -Path ".\$Guid" -ChildPath "process_list.csv") -ErrorAction SilentlyContinue
    Move-Item -Path process_list.json -Destination $(Join-Path -Path ".\$Guid" -ChildPath "process_list.json") -ErrorAction SilentlyContinue
    
    # Copy Debug Log
    Copy-Item -Path debug.log -Destination $(Join-Path -Path ".\$Guid" -ChildPath "debug.log") -ErrorAction SilentlyContinue

    # Package Metadata
    # We set $session in Stop-Session
    <#
    $session = Get-Content .activesession | ConvertFrom-Json
    $session.session_id = $Guid
    $session.end_time = $EndTime
    #>
    # Force metadata times to always be in UTC
    if ($config.desktop -eq "true")
    {
        $session.hosts.start_time = (Get-Date -Date $VideoStartTime).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ss.ffffffZ')
        $session.hosts.end_time = (Get-Date -Date $VideoEndTime).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ss.ffffffZ')
    }
    else 
    {
        $session.hosts.start_time = (Get-Date -Date $session.start_time).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ss.ffffffZ')
        $session.hosts.end_time = (Get-Date -Date $session.end_time).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ss.ffffffZ')
    }
    $session.start_time = (Get-Date -Date $session.start_time).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ss.ffffffZ')
    $session.end_time = (Get-Date -Date $session.end_time).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ss.ffffffZ')
    ConvertTo-Json $session | Out-File -FilePath $(Join-Path -Path ".\$Guid" -ChildPath "metadata.json") -Encoding ASCII

    # Save to .zip archive
    # TODO: Surpress compressing progress status
    # TODO: Set 'CompressionLevel' to 'Fastest', 'NoCompression', or 'Optimal' (default)
    # For an average sized session...
    # CompressionLevel Optimal: 13.22s / 22,628 KB
    # CompressionLevel Fastest: 12.45s / 23,600 KB
    # CompressionLevel NoCompression: 12.05s / 87,018 KB
    Write-Host "[*] Compressing session into archive"
    if ($Name) {
        $zipname = $Name
    } else {
        $timestamp = (Get-Date -Format "yyyyMMdd_hhmmss")
        $default_name = "$($timestamp)_$($HostName)"
        if ($Headless){
            $confirmation = $default_name
        } else {
            $confirmation = Read-Host "[*] Enter Zip Name (default: $($default_name))"
        }
        $confirmation = $confirmation -replace '\s','_'
        if ( ($confirmation.ToLower().Trim() -eq '')) 
        {
            $zipname = $default_name
        } 
        else 
        {
            $zipname = $confirmation
        }
    }
    $zipname = $zipname -replace "\.zip$"
    if (Test-Path $zipname".zip" -PathType Leaf) {
        if ($Headless) {
            $overwrite = "y"
        } else {
            $overwrite = Read-Host "[!] File already exists. Do you want to overwrite? [y/n]"
        }
        if ( -not (($overwrite.ToLower().Trim() -eq 'y') -or ($overwrite.ToLower().Trim() -eq 'yes')) ) {
            while (Test-Path $zipname".zip" -PathType Leaf) {
                $zipname = Read-Host "[!] Enter new name for file: "
                $zipname = $zipname -replace ".zip"
            }
        }    
    }
    if ($IsLinux -and $sudoer)
    {
        Invoke-Expression -Command "chown -R $sudoer`:$sudoer $Guid" | Out-Null
    }
    $null = Compress-Archive -Path $Guid -DestinationPath $zipname".zip" -Force
    
    Remove-Item $Guid -Recurse -Force -ErrorAction SilentlyContinue

    # Remove active session
    # NOTE: must use -Force
    # Remove-Item: You do not have sufficient access rights to perform this operation or the item is hidden, system, or read only.
    Remove-Item -Path .activesession -Force -ErrorAction SilentlyContinue
    if ($IsLinux -and $sudoer)
    {
        Invoke-Expression -Command "chown $sudoer`:$sudoer $zipname.zip" | Out-Null
    }
    # Notify the user
    Write-Host -ForegroundColor Green "[*] Session has been saved to $($zipname).zip"
}

function Restore-Time
{

    # Restore Timezone
    Write-Host "[*] Restoring timezone and clock"

    # Hide seconds on clock
    if ($IsWindows)
    {

        # Set-TimeZone was added to PowerShell 5.1
        # tzutil has been shipped since Windows 7

        <#
        Set-TimeZone -Id $id
        #>

        $Id = Get-Content .tz
        Invoke-Expression -Command "tzutil /s ""$Id"""
        Remove-Item -Path .tz -Force -ErrorAction SilentlyContinue

        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSecondsInSystemClock" -Value 0 -PropertyType "DWORD" -force | Out-Null
        
        $TimeFormat = Get-Content .timeformat
        New-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sTimeFormat" -Value $TimeFormat -PropertyType "String" -force | Out-Null
        Remove-Item -Path .timeformat -Force -ErrorAction SilentlyContinue
        try {
            Stop-Process -ProcessName explorer # requires explorer to be restarted
        } catch {
            Write-Output "[!] Failed to restart explorer."
        }
    } 
    elseif ($IsLinux) 
    {

        $tz = Get-Content .tz
        Remove-Item -Path .tz -Force
        Invoke-Expression -Command "timedatectl set-timezone ""$tz"" >/dev/null 2>&1" | Out-Null
        if ($sudoer)
        {
            if (Test-Path "$( getent passwd "$sudoer" | cut -d: -f6 )/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" -PathType Leaf) {
                # XFCE
                $dateformat = Get-Content .dateformat
                Remove-Item -Path .dateformat -Force
                $plugin = Invoke-Expression -Command "cat $( getent passwd "$sudoer" | cut -d: -f6 )/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml | grep clock | awk -F'\`"' '{print `$2}'"
                Invoke-Expression -Command "pkexec --user $sudoer env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $sudoer)/bus xfconf-query -c xfce4-panel -p /plugins/$plugin/digital-time-format -s ""$dateformat""" | Out-Null
            } else {
            # Gnome
                Invoke-Expression -Command "gsettings set org.gnome.desktop.interface clock-show-seconds false" | Out-Null
            }
        }

    } 
    elseif ($IsMacOS)
    {
        # Change timezone
        $tz = Get-Content .tz
        Remove-Item -Path .tz -Force
        Invoke-Expression -Command "systemsetup -settimezone ""$tz"""
        
        # Default appears to be "EEE MMM d  j:mm a", but we should back theirs up and then restore it
        # NOTE: we need to drop privs for these commands to it changes the user's plist

        # These are in ~/Library/Preferences/
        if ($sudoer)
        {
            # https://github.com/tech-otaku/menu-bar-clock
            $dateformat = Get-Content .dateformat
            Remove-Item -Path .dateformat -Force
            Invoke-Expression -Command "sudo -u $sudoer defaults write com.apple.menuextra.clock.plist DateFormat -string ""$dateformat"""
            Invoke-Expression -Command "sudo -u $sudoer defaults delete com.apple.menuextra.clock.plist IsAnalog -bool false"
            Invoke-Expression -Command "sudo -u $sudoer defaults delete com.apple.menuextra.clock.plist ShowDayOfWeek -bool false"
            Invoke-Expression -Command "sudo -u $sudoer defaults delete com.apple.menuextra.clock.plist ShowDayOfMonth -bool false"
            Invoke-Expression -Command "sudo -u $sudoer defaults delete com.apple.menuextra.clock.plist Show24Hour -bool true"
            Invoke-Expression -Command "sudo -u $sudoer defaults delete com.apple.menuextra.clock.plist ShowSeconds -bool true"
            Invoke-Expression -Command "sudo -u $sudoer defaults delete com.apple.menuextra.clock.plist ShowAMPM -bool false"

            # Pre Big Sur
            # killall SystemUIServer
            killall ControlCenter

        }

    }

}
