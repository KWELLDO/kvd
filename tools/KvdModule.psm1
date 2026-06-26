# KvdModule.psm1 — KWD Versioned Document v2 (with delta storage)
using namespace System.Text
using namespace System.IO
using namespace System.Collections.Generic

function Compute-KvdHash {
    param([string]$ParentHash, [string]$Content, [string]$Author, [string]$Date, [string]$Message)
    $inputStr = "$ParentHash$Content$Author$Date$Message"
    $bytes = [Text.Encoding]::UTF8.GetBytes($inputStr)
    $hashBytes = [Security.Cryptography.SHA256]::HashData($bytes)
    return -join ($hashBytes[0..3] | ForEach-Object { $_.ToString('x2') })
}

function Get-ForwardDiff {
    param([string]$OldContent, [string]$NewContent)
    $oldLines = $OldContent -split "`n"
    $newLines = $NewContent -split "`n"
    $diff = [List[string]]::new()
    $i = 0
    while ($i -lt $oldLines.Count -or $i -lt $newLines.Count) {
        $old = if ($i -lt $oldLines.Count) { $oldLines[$i] } else { $null }
        $new = if ($i -lt $newLines.Count) { $newLines[$i] } else { $null }
        if ($old -ne $new) {
            $chunkOld = [List[string]]::new()
            $chunkNew = [List[string]]::new()
            $startIdx = $i
            while ($i -lt $oldLines.Count -or $i -lt $newLines.Count) {
                $o = if ($i -lt $oldLines.Count) { $oldLines[$i] } else { $null }
                $n = if ($i -lt $newLines.Count) { $newLines[$i] } else { $null }
                if ($o -eq $n) { break }
                if ($o -ne $null) { [void]$chunkOld.Add($o) }
                if ($n -ne $null) { [void]$chunkNew.Add($n) }
                $i++
            }
            if ($chunkOld.Count -gt 0 -or $chunkNew.Count -gt 0) {
                [void]$diff.Add("@@ $startIdx,$($chunkOld.Count),$($chunkNew.Count) @@")
                foreach ($ln in $chunkOld) { [void]$diff.Add("-$ln") }
                foreach ($ln in $chunkNew) { [void]$diff.Add("+$ln") }
            }
        } else { $i++ }
    }
    return ($diff -join "`n")
}

function Apply-ForwardDiff {
    param([string]$Content, [string]$Diff)
    if ([string]::IsNullOrEmpty($Diff.Trim())) { return $Content }
    $lines = $Content -split "`n"
    $diffLines = $Diff -split "`n"
    $result = [List[string]]::new()
    $srcIdx = 0; $i = 0
    while ($i -lt $diffLines.Count) {
        $line = $diffLines[$i]
        if ($line -match "^@@ (\d+),(\d+),(\d+) @@$") {
            $start = [int]$matches[1]; $removed = [int]$matches[2]; $added = [int]$matches[3]
            while ($srcIdx -lt $start -and $srcIdx -lt $lines.Count) { [void]$result.Add($lines[$srcIdx]); $srcIdx++ }
            $srcIdx += $removed
            $i++; $addedCount = 0
            while ($addedCount -lt $added -and $i -lt $diffLines.Count) {
                $dl = $diffLines[$i]
                if ($dl.StartsWith("+")) { [void]$result.Add($dl.Substring(1)); $addedCount++ }
                $i++
            }
        } else { $i++ }
    }
    while ($srcIdx -lt $lines.Count) { [void]$result.Add($lines[$srcIdx]); $srcIdx++ }
    return ($result -join "`n")
}

function Get-DiffText {
    param([string]$OldContent, [string]$NewContent)
    $oldLines = ($OldContent -split "`n")
    $newLines = ($NewContent -split "`n")
    $diff = [List[string]]::new()
    $maxLen = [Math]::Max($oldLines.Count, $newLines.Count)
    for ($i = 0; $i -lt $maxLen; $i++) {
        $old = if ($i -lt $oldLines.Count) { $oldLines[$i] } else { $null }
        $new = if ($i -lt $newLines.Count) { $newLines[$i] } else { $null }
        if ($old -ne $new) {
            if ($old -ne $null) { [void]$diff.Add("--- $old") }
            if ($new -ne $null) { [void]$diff.Add("+++ $new") }
        }
    }
    if ($diff.Count -eq 0) { return "(no changes)" }
    return $diff -join "`n"
}

function Parse-KvdDocument {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }

    $lines = [File]::ReadAllLines($Path, [Text.Encoding]::UTF8)

    $doc = [PSCustomObject]@{
        Title         = ""
        Created       = [DateTime]::UtcNow
        CurrentContent = ""
        Commits       = [List[hashtable]]::new()
    }

    $mode = "header"
    $currentCommit = $null
    $commitContent = [List[string]]::new()
    $inBody = $false

    foreach ($line in $lines) {
        if ($mode -eq "header") {
            if ($line -eq "--CURRENT--") { $mode = "current"; continue }
            if ($line -match "^Title:\s*(.*)$") { $doc.Title = $matches[1] }
            if ($line -match "^Created:\s*(.*)$") {
                try { $doc.Created = [datetime]::Parse($matches[1], $null, [System.Globalization.DateTimeStyles]::RoundtripKind) } catch {}
            }
            continue
        }
        if ($mode -eq "current") {
            if ($line -eq "--COMMITS--") { $mode = "commits"; continue }
            if ($doc.CurrentContent -eq "") { $doc.CurrentContent = $line }
            else { $doc.CurrentContent += "`n$line" }
            continue
        }
        if ($mode -eq "commits") {
            if ($line -match "^>>> (\d+) \| ([a-f0-9]+)$") {
                $currentCommit = @{
                    Revision = [int]$matches[1]
                    Hash = $matches[2]
                    Type = "full"
                    Author = ""
                    Date = [DateTime]::UtcNow
                    Message = ""
                    ParentRevision = 0
                    Content = ""
                }
                $commitContent = [List[string]]::new()
                $inBody = $false
                continue
            }
            if ($currentCommit -ne $null -and -not $inBody) {
                if ($line -match "^author:(.*)$") { $currentCommit.Author = $matches[1]; continue }
                if ($line -match "^type:(.*)$") { $currentCommit.Type = $matches[1].Trim(); continue }
                if ($line -match "^date:(.*)$") {
                    try { $currentCommit.Date = [datetime]::Parse($matches[1], $null, [System.Globalization.DateTimeStyles]::RoundtripKind) } catch {}
                    continue
                }
                if ($line -match "^msg:(.*)$") { $currentCommit.Message = $matches[1]; continue }
                if ($line -match "^parent:\s*(\d+)") { $currentCommit.ParentRevision = [int]$matches[1]; continue }
                if ($line -eq "parent:") { $currentCommit.ParentRevision = 0; continue }
                if ($line -eq "---") { $inBody = $true; continue }
                continue
            }
            if ($currentCommit -ne $null -and $inBody) {
                if ($line -match "^<<< \d+$") {
                    $currentCommit.Content = $commitContent -join "`n"
                    $doc.Commits.Add($currentCommit)
                    $currentCommit = $null
                    $inBody = $false
                } else {
                    $commitContent.Add($line)
                }
                continue
            }
        }
    }

    # Reconstruct delta commits (walk oldest to newest, applying forward diffs)
    $sorted = $doc.Commits | Sort-Object Revision
    foreach ($c in $sorted) {
        if ($c.Type -eq "delta") {
            $parent = $sorted | Where-Object { $_.Revision -eq $c.ParentRevision } | Select-Object -First 1
            if ($parent -and $parent.Content) {
                $c.Content = Apply-ForwardDiff -Content $parent.Content -Diff $c.Content
                $c.Type = "full"
            }
        }
    }

    return $doc
}

function Write-KvdDocument {
    param([string]$Path, $Doc)
    $sb = [StringBuilder]::new()

    [void]$sb.AppendLine("KVD/v2")
    if ($Doc.Title) { [void]$sb.AppendLine("Title: $($Doc.Title)") }
    [void]$sb.AppendLine("Created: $($Doc.Created.ToString('o'))")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("--CURRENT--")
    if ($Doc.CurrentContent) { [void]$sb.AppendLine($Doc.CurrentContent) }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("--COMMITS--")

    foreach ($c in $Doc.Commits) {
        [void]$sb.AppendLine(">>> $($c.Revision) | $($c.Hash)")
        [void]$sb.AppendLine("author:$($c.Author)")
        [void]$sb.AppendLine("type:$($c.Type)")
        [void]$sb.AppendLine("date:$($c.Date.ToString('o'))")
        [void]$sb.AppendLine("msg:$($c.Message)")
        if ($c.ParentRevision -gt 0) {
            [void]$sb.AppendLine("parent:$($c.ParentRevision)")
        } else {
            [void]$sb.AppendLine("parent:")
        }
        [void]$sb.AppendLine("---")
        if ($c.Content) { [void]$sb.AppendLine($c.Content) }
        [void]$sb.AppendLine("<<< $($c.Revision)")
    }

    $content = $sb.ToString().TrimEnd() + "`n"
    [File]::WriteAllText($Path, $content, [Text.Encoding]::UTF8)
}

function New-KvdFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path,
        [Parameter(Position=1)][string]$Content = "",
        [Parameter(Mandatory)][string]$Author,
        [Parameter()][string]$Message = "Initial commit",
        [Parameter()][string]$Title = ""
    )
    if (-not $Path.EndsWith(".kvd")) { $Path += ".kvd" }
    if (Test-Path $Path) { throw "File already exists: $Path" }

    $now = [DateTime]::UtcNow
    $title = if ($Title) { $Title } else { [Path]::GetFileNameWithoutExtension($Path) }
    $hash = Compute-KvdHash -ParentHash "" -Content $Content -Author $Author -Date ($now.ToString("o")) -Message $Message

    $commit = @{
        Revision = 1
        Hash = $hash
        Type = "full"
        Author = $Author
        Date = $now
        Message = $Message
        ParentRevision = 0
        Content = $Content
    }

    $doc = [PSCustomObject]@{
        Title = $title
        Created = $now
        CurrentContent = $Content
        Commits = [List[hashtable]]::new()
    }
    $doc.Commits.Add($commit)

    Write-KvdDocument -Path $Path -Doc $doc
    Write-Output "Created KVD file: $Path"
}

function Set-KvdContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path,
        [Parameter(Mandatory, Position=1)][string]$Content,
        [Parameter(Mandatory)][string]$Author,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }

    $doc = Parse-KvdDocument -Path $Path
    $lastCommit = $doc.Commits | Sort-Object Revision -Descending | Select-Object -First 1
    $newRevision = if ($lastCommit) { $lastCommit.Revision + 1 } else { 1 }
    $now = [DateTime]::UtcNow
    $parentHash = if ($lastCommit) { $lastCommit.Hash } else { "" }
    $parentRev  = if ($lastCommit) { $lastCommit.Revision } else { 0 }
    $hash = Compute-KvdHash -ParentHash $parentHash -Content $Content -Author $Author -Date ($now.ToString("o")) -Message $Message

    # Save full content for diff display before converting to delta
    $oldFullContent = if ($lastCommit) { $lastCommit.Content } else { "" }

    # Convert old latest from full to delta (if it has a parent)
    if ($lastCommit -and $lastCommit.ParentRevision -gt 0) {
        $parent = $doc.Commits | Where-Object { $_.Revision -eq $lastCommit.ParentRevision } | Select-Object -First 1
        if ($parent -and $parent.Content) {
            $lastCommit.Content = Get-ForwardDiff -OldContent $parent.Content -NewContent $lastCommit.Content
            $lastCommit.Type = "delta"
        }
    }

    $commit = @{
        Revision = $newRevision
        Hash = $hash
        Type = "full"
        Author = $Author
        Date = $now
        Message = $Message
        ParentRevision = $parentRev
        Content = $Content
    }
    $doc.Commits.Add($commit)
    $doc.CurrentContent = $Content

    Write-KvdDocument -Path $Path -Doc $doc

    $diffText = Get-DiffText -OldContent ($oldFullContent) -NewContent $Content
    Write-Output "Committed revision $newRevision | $hash"
    Write-Output "Author: $Author | $($now.ToString("o"))"
    Write-Output "Message: $Message"
    Write-Output "--- Diff ---"
    Write-Output $diffText
}

function Get-KvdContent {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position=0)][string]$Path)
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path
    Write-Output $doc.CurrentContent
}

function Get-KvdHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path,
        [switch]$Detailed
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path

    Write-Output "======================================="
    Write-Output " KVD History: $($doc.Title)"
    Write-Output " Created: $($doc.Created.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output "======================================="
    Write-Output ""

    if ($doc.Commits.Count -eq 0) { Write-Output "(no commits)"; return }

    $prevContent = ""
    foreach ($c in $doc.Commits | Sort-Object Revision) {
        Write-Output "---------------------------------------"
        Write-Output "  Rev $($c.Revision) | $($c.Hash)"
        Write-Output "  Author: $($c.Author)"
        Write-Output "  Date:   $($c.Date.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Output "  Msg:    $($c.Message)"
        if ($c.ParentRevision -gt 0) {
            Write-Output "  Parent: rev $($c.ParentRevision)"
        } else {
            Write-Output "  Parent: (initial commit)"
        }
        if ($Detailed) {
            Write-Output ""
            Write-Output "  Changes:"
            $diffText = Get-DiffText -OldContent $prevContent -NewContent $c.Content
            $diffText -split "`n" | ForEach-Object { Write-Output "    $_" }
        }
        Write-Output ""
        $prevContent = $c.Content
    }
    Write-Output "---------------------------------------"
    Write-Output "  $($doc.Commits.Count) commit(s)"
}

function Get-KvdCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path,
        [Parameter(Mandatory, Position=1)][int]$Revision
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path
    $commit = $doc.Commits | Where-Object { $_.Revision -eq $Revision } | Select-Object -First 1
    if (-not $commit) { throw "Revision $Revision not found" }

    Write-Output "=== Rev $Revision | $($commit.Hash) ==="
    Write-Output "Author: $($commit.Author)"
    Write-Output "Date:   $($commit.Date.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output "Msg:    $($commit.Message)"
    Write-Output ""
    Write-Output $commit.Content
}

function Compare-KvdCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path,
        [Parameter(Position=1)][int]$FromRevision = -1,
        [Parameter(Position=2)][int]$ToRevision = -1
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path
    $sorted = $doc.Commits | Sort-Object Revision
    if ($ToRevision -eq -1) { $ToRevision = ($sorted | Select-Object -Last 1).Revision }
    if ($FromRevision -eq -1) {
        $to = $sorted | Where-Object { $_.Revision -eq $ToRevision } | Select-Object -First 1
        if (-not $to) { throw "Revision $ToRevision not found" }
        $FromRevision = if ($to.ParentRevision -gt 0) { $to.ParentRevision } else { 0 }
    }
    $from = if ($FromRevision -gt 0) { $sorted | Where-Object { $_.Revision -eq $FromRevision } | Select-Object -First 1 } else { $null }
    $to   = $sorted | Where-Object { $_.Revision -eq $ToRevision } | Select-Object -First 1
    if (-not $to) { throw "Revision $ToRevision not found" }

    $oldContent = if ($from) { $from.Content } else { "" }
    $newContent = $to.Content
    Write-Output "=== Diff Rev $FromRevision -> Rev $ToRevision ==="
    Write-Output "From: $($from.Message)"
    Write-Output "To:   $($to.Message)"
    Write-Output ""
    Write-Output (Get-DiffText -OldContent $oldContent -NewContent $newContent)
}

function Test-KvdFile {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position=0)][string]$Path)
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path

    Write-Output "Verifying: $Path"
    $ok = $true
    foreach ($c in $doc.Commits | Sort-Object Revision) {
        $parentHash = if ($c.ParentRevision -gt 0) {
            $parent = $doc.Commits | Where-Object { $_.Revision -eq $c.ParentRevision } | Select-Object -First 1
            if ($parent) { $parent.Hash } else { "" }
        } else { "" }

        $expectedHash = Compute-KvdHash -ParentHash $parentHash -Content $c.Content -Author $c.Author -Date ($c.Date.ToString("o")) -Message $c.Message
        if ($expectedHash -eq $c.Hash) {
            Write-Output "  [OK] Rev $($c.Revision) | $($c.Hash)"
        } else {
            Write-Output "  [FAIL] Rev $($c.Revision) | expected $expectedHash, got $($c.Hash)"
            $ok = $false
        }
    }
    if ($ok) { Write-Output "Hash chain valid." }
    else { Write-Output "Hash chain BROKEN -- file may be tampered!" }
}

function Export-KvdContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path,
        [Parameter(Position=1)][int]$Revision = -1,
        [Parameter(Position=2)][string]$OutputPath = ""
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $out = if ($OutputPath -eq "") { [Path]::ChangeExtension($Path, ".txt") } else { $OutputPath }
    if ($Revision -eq -1) {
        Get-KvdContent -Path $Path | Out-File -FilePath $out -Encoding utf8
    } else {
        Get-KvdCommit -Path $Path -Revision $Revision | Out-File -FilePath $out -Encoding utf8
    }
    Write-Output "Exported to: $out"
}

function Show-KvdFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0, ValueFromPipeline)][string]$Path
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path
    $tempFile = [Path]::GetTempFileName() + ".txt"
    [File]::WriteAllText($tempFile, $doc.CurrentContent, [Text.Encoding]::UTF8)
    Write-Host "Opening: $Path" -ForegroundColor Cyan
    Write-Host "KVD: $($doc.Title) | $($doc.Commits.Count) commit(s)" -ForegroundColor DarkGray
    Write-Host "Tip: changes to temp file won't auto-save. Use Set-KvdContent to commit." -ForegroundColor Yellow
    Start-Process notepad.exe -ArgumentList "`"$tempFile`""
}

function Show-KvdHistoryView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Path
    )
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $doc = Parse-KvdDocument -Path $Path
    $html = [StringBuilder]::new()
    [void]$html.AppendLine('<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">')
    [void]$html.AppendLine("<title>KVD Viewer -- $($doc.Title)</title>")
    [void]$html.AppendLine('<style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,"Segoe UI",sans-serif;background:#f5f5f5;color:#1a1a1a;padding:20px}
        .header{background:#2d2d2d;color:#fff;padding:16px 24px;border-radius:8px 8px 0 0}
        .header h1{font-size:18px;font-weight:600}
        .header span{font-size:12px;color:#aaa;margin-left:12px}
        .tabs{display:flex;background:#e0e0e0;border-left:1px solid #ccc;border-right:1px solid #ccc}
        .tab{padding:8px 20px;cursor:pointer;font-size:13px;border:none;background:#e0e0e0}
        .tab.active{background:#fff;font-weight:600;border-bottom:2px solid #2d2d2d}
        .panel{background:#fff;padding:20px;border:1px solid #ccc;border-top:none;border-radius:0 0 8px 8px;min-height:200px}
        .panel pre{font-family:"Cascadia Code","JetBrains Mono",Consolas,monospace;font-size:13px;line-height:1.6;white-space:pre-wrap}
        .commit{padding:12px 0;border-bottom:1px solid #eee}
        .commit:last-child{border:none}
        .commit .rev{color:#2d2d2d;font-weight:600;font-size:14px}
        .commit .meta{color:#666;font-size:12px}
        .commit .msg{color:#0066cc;font-size:13px}
        .commit .content{margin-top:8px;padding:8px;background:#f9f9f9;border-radius:4px;font-family:monospace;font-size:12px;white-space:pre-wrap;display:none}
        .show-content{font-size:11px;color:#0066cc;cursor:pointer}
    </style></head><body>')

    [void]$html.AppendLine("<div class=header><h1>$($doc.Title) <span>$($doc.Created.ToString('yyyy-MM-dd HH:mm:ss')) | $($doc.Commits.Count) commit(s)</span></h1></div>")
    [void]$html.AppendLine('<div class=tabs><button class="tab active" onclick=showPanel(0)>Content</button><button class=tab onclick=showPanel(1)>History</button></div>')

    $encContent = [System.Web.HttpUtility]::HtmlEncode($doc.CurrentContent)
    [void]$html.AppendLine("<div class=panel id=panel0><pre>$encContent</pre></div>")
    [void]$html.AppendLine("<div class=panel id=panel1 style=display:none>")

    foreach ($c in $doc.Commits | Sort-Object Revision -Descending) {
        [void]$html.AppendLine("<div class=commit><div class=rev>Rev $($c.Revision) | $($c.Hash)</div>")
        [void]$html.AppendLine("<div class=meta>$($c.Author) | $($c.Date.ToString('yyyy-MM-dd HH:mm:ss'))</div>")
        [void]$html.AppendLine("<div class=msg>$($c.Message)</div>")
        $encCommit = [System.Web.HttpUtility]::HtmlEncode($c.Content)
        [void]$html.AppendLine("<div class=content id=content-$($c.Revision)>$encCommit</div>")
        [void]$html.AppendLine("<span class=show-content onclick=toggleContent($($c.Revision))>Show full content</span></div>")
    }

    [void]$html.AppendLine('</div><script>
    function showPanel(n){document.querySelectorAll(".panel").forEach(p=>p.style.display="none");document.getElementById("panel"+n).style.display="";document.querySelectorAll(".tab").forEach((t,i)=>t.className="tab"+(i===n?" active":""))}
    function toggleContent(r){var e=document.getElementById("content-"+r);e.style.display=e.style.display==="none"?"block":"none"}
    </script></body></html>')

    $tempFile = [Path]::GetTempFileName() + ".html"
    [File]::WriteAllText($tempFile, $html.ToString(), [Text.Encoding]::UTF8)
    Start-Process $tempFile
}

Export-ModuleMember -Function @(
    "New-KvdFile", "Set-KvdContent", "Get-KvdContent", "Get-KvdHistory",
    "Get-KvdCommit", "Compare-KvdCommit", "Test-KvdFile", "Export-KvdContent",
    "Show-KvdFile", "Show-KvdHistoryView"
)

