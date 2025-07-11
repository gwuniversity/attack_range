@{
    # Script module or binary module file associated with this manifest.
    ModuleToProcess = 'capattack.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0.0'

    # ID used to uniquely identify this module
    GUID = 'c5952959-be84-4f19-a6fa-858a76b67a7c'

    # Author of this module
    Author = 'Team SnapAttack'

    # Copyright statement for this module
    Copyright = 'MIT'

    # Description of the functionality provided by this module
    Description = 'Captures cyber attacks to create a threat library'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '3.0'

    # Functions to export from this module
    FunctionsToExport = @(
        'Start-Capattack',
        'Capattack-Start',
        'Stop-Capattack',
        'Capattack-Stop',
        'CapAttack-Status',
        'Install-Capattack'
    )
}