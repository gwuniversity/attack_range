function CapAttack-Status 
{

    # Check if session is recording
    if (Test-Path .activesession -PathType Leaf) 
    {
        Write-Host -ForegroundColor Green "{*] An active session is in progress"
        # TODO: friendly time since the session started
    } 
    else 
    {
        Write-Host -ForegroundColor Red "{*] No active session"
    }

}