@{
    RootModule        = 'KvdModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID             = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author           = 'Codex'
    CompanyName      = 'KWD'
    Copyright        = '(c) 2026 KWD. All rights reserved.'
    Description      = 'PowerShell module for KVD (KWD Versioned Document) — a self-versioned file format with built-in change tracking.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'New-KvdFile',
        'Set-KvdContent',
        'Get-KvdContent',
        'Get-KvdHistory',
        'Get-KvdCommit',
        'Compare-KvdCommit',
        'Test-KvdFile',
        'Export-KvdContent'
    )
    FileList         = @('KvdModule.psm1')
}
