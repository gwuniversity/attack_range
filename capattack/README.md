# CapAttack

The client capture agent. Need a domain controller, exchange server, web server, or some other complex environment? Now, you can capture your own attack sessions locally.

This is an **alpha** project. It supports Windows, Linux (Kali), and maybe MacOS.  It has been tested against Windows 10 (20H2), Kali (2021.1), and MacOS Big Sur (11.0.1)

On Kali, PowerShell occasionally does not install properly.  You'll get errors like "The SSL connection could not be established, see inner exception."  The fix is just to run `apt remove powershell` and `apt install powershell`.

DON'T USE ON A MAC. You've been warned. On first run, you will need to grant ffmpeg (terminal) permissions to record your screen.  This will also require terminal to be restarted.  Because of retina displays, ffmpeg will cause your computer to run like a jet engine and it won't respond to SIGINT like it is supposed to, meaning the video will be corrupted.

## Compatibility
| Windows | Linux | MacOS |
| --- | --- | --- |
| Requires PowerShell 3.0+ | Requires PowerShell 6+ | Requires PowerShell 6+ |
| Full support | Only captures keystrokes and desktop | Only captures desktop |

Linux and MacOS are intended to only be used as attackers for now, until logging is on par with what Sysmon collects on Windows.

## Usage

**Administrator/root privileges are required to use the tool.**

You may need to add `Set-ExecutionPolicy bypass` on first run if you get warnings about unsigned modules, etc.

1) Clone this repository locally or download a release
2) Review `config.ini`, verify the `machine_type` (attacker or victim) and any other settings
3a) On Windows, launch an elevated powershell prompt and run `Import-Module .\capattack.psd1`
3b) On Mac or Linux, open a terminal and use `sudo` to launch `pwsh`.  Then run `Import-Module ./capattack.psd1`

There are four commands:

`Start-Capattack` will start a new session

`CapAttack-Status` will let you know if a session is active or not

`Stop-Capattack` will stop the current session.  If things go really wrong, you can do `Stop-Capattack -force $true` or just `Stop-Capattack $true` to do a force stop.  It won't try to package up the session data if you use the force option.

`Install-Capattack` will pre-install software (~~keylogger~~, ffmpeg, tshark) and configure the host for logging, timezone, etc.  This is intended to be run *once*. The `-Shortcuts` parameter will also create two scheduled tasks (`Start-Capattack` and `Stop-Capattack`) that you can use that will auto elevate to the proper permisison level, change to the correct directory, import the modules, and execute starts/stops.

## Running without a user session

Typical use of CapAttack uses an interactive session to capture the session. There are occasions where you want to automate actions.
There are two config options to set to enable automated headless capture. **headless** will automatically accept all prompts. **desktop=false** will disable video capture which would break since there is no active user session logged in. You will want to run `Install-Capattack` with `-Shortcuts` and use those Tasks to start and stop capture.

## Configuration

The **machine_type** dictates most of the logging options.  Attackers will only ever log desktop and keystrokes.  Victims may log additional information.

On Windows, can configure advanced logging (sysmon, auditpol, powershell) as well two different video capture options:

1) **gdigrab** is built-in to ffmpeg and automatically records the full desktop. It does NOT work with UAC prompts, and will crash if the secure desktop is brought up.  We lower the UAC settings via the registry to ensure this works.  If for some reason your session requires the secure desktop, consider using **dshow** instead.

2) **dshow** uses a directshow capture filter to record the screen, which is provided as a DLL.  It will not capture the secure desktop either when a UAC prompt is brought up, but it won't crash.

Linux uses **x11grab** that is built into ffmpeg for desktop recording.  Similarly, MacOS uses **avfoundation** that is built into ffmpeg.  These are default and do not require any special configuration.

```
[General]
# supported options: attacker,victim
machine_type=victim

[Logging]
### ATTACKER/VICTIM OPTIONS ###
# Records desktop with ffmpeg
desktop=true

# Windows capture device options: gdigrab,dshow
# Note: Windows only
ffmpeg_recorder=gdigrab

# Records keystrokes
keystrokes=true


##### VICTIM ONLY OPTIONS #####
# how to pull event logs from the system
# supported options include: raw, xml (deprecated)
# Note: windows only
log_format=raw

# clear event logs prior to session start
# Note: windows only
clear_event_logs=true

# supported options include: sysmon, none
edr=sysmon

# sysmon configuration to use; placed in same directory as this script
# Note: Windows only
sysmon_config=sysmon_snapattack.xml

# Configures audit policy logs, such as 4688
# Note: Windows only
auditpol=true

# configures PowerShell v5 module and script block logging
# Note: Windows only
powershell_module_scriptblock=true

# Configures packet capture
# Note: windows only
pcap=true

```

## Third-Party Libraries
This software utilizes third-party and open-source libraries governed by their respective licenses.

- ffmpeg - https://github.com/FFmpeg/FFmpeg/blob/master/LICENSE.md
- ffmpeg_wrapper - https://github.com/RattleyCooper/ffmpeg_wrapper/blob/master/LICENSE
- Sysmon - https://learn.microsoft.com/en-us/sysinternals/license-terms
- Wireshark - https://gitlab.com/wireshark/wireshark/-/blob/master/COPYING
- NPcap - https://npcap.com/oem/internal.html
- Win10Pcap - https://www.win10pcap.org/license/
- dategrep - https://github.com/mdom/dategrep/blob/master/LICENSE
- xstat - https://github.com/bernd-wechner/Linux-Tools/blob/master/LICENSE.md
