# kvd-viewer.ps1 — 独立 KVD 查看器（不依赖模块）
# 用法: pwsh -NoProfile kvd-viewer.ps1 file.kvd
# 可关联到 .kvd 文件类型，双击即可查看

param(
    [Parameter(Mandatory, Position=0)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    Write-Host "Usage: pwsh -NoProfile `"$PSCommandPath`" <file.kvd>"
    exit 1
}

# Simple KVD parser — just extract content between --CURRENT-- and --COMMITS--
$raw = Get-Content $FilePath -Raw -Encoding utf8

# Extract title
$title = "untitled"
if ($raw -match '(?m)^Title:\s*(.*)$') { $title = $matches[1] }

# Extract current content
$content = ""
$match = [regex]::Match($raw, '(?s)--CURRENT--\s*\n(.*?)\n\s*--COMMITS--')
if ($match.Success) {
    $content = $match.Groups[1].Value.TrimEnd()
} else {
    Write-Host "Invalid KVD file: $FilePath" -ForegroundColor Red
    exit 1
}

# Count commits
$commitCount = ([regex]::Matches($raw, '(?m)^>>> \d+ \| ')).Count

# Show in Notepad with header info
$tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
$infoLine = "╔═══════════════════════════════════════════════╗"
$infoLine += "`n║  KVD File: $(Split-Path $FilePath -Leaf)".PadRight(48) + "║"
$infoLine += "`n║  Title: $title".PadRight(48) + "║"
$infoLine += "`n║  Commits: $commitCount".PadRight(48) + "║"
$infoLine += "`n╚═══════════════════════════════════════════════╝"
$infoLine += "`n`n"

# Add note about editing
$note = "`n`n---`n"
$note += "// This is a read-only view of the KVD file.`n"
$note += "// To edit, use: Set-KvdContent -Path `"$FilePath`" -Content `"...`" -Author `"...`" -Message `"...`"`n"
$note += "// Module: Import-Module D:\KWD\kvd\tools\KvdModule.psm1"

$displayContent = $infoLine + $content + $note
Set-Content -Path $tempFile -Value $displayContent -Encoding utf8

Start-Process notepad.exe -ArgumentList "`"$tempFile`""
