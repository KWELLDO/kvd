# KVD Demo Script
using namespace System.IO

Import-Module D:\KWD\kvd\tools\KvdModule.psm1 -Force

$demoFile = [Path]::GetFullPath("$PSScriptRoot/examples/demo.kvd")

Write-Host "=== Step 1: Create new KVD file ===" -ForegroundColor Green
New-KvdFile -Path $demoFile -Author "codex" -Message "Create project plan" -Content @"
# Project Alpha

## 目标
开发下一代 AI 辅助工具

## 时间线
- 2026 Q3: 原型开发
- 2026 Q4: 内部测试
"@

Write-Host "`n=== Step 2: Show history ===" -ForegroundColor Green
Get-KvdHistory -Path $demoFile

Write-Host "`n=== Step 3: Update content ===" -ForegroundColor Green
Set-KvdContent -Path $demoFile -Author "user" -Message "Add timeline and team" -Content @"
# Project Alpha

## 目标
开发下一代 AI 辅助工具

## 时间线
- 2026 Q3: 原型开发
- 2026 Q4: 内部测试
- 2027 Q1: 公测发布
- 2027 Q2: 正式上线

## 团队成员
- Alice (PM)
- Bob (Dev)
- Carol (Design)
"@

Write-Host "`n=== Step 4: Detailed history ===" -ForegroundColor Green
Get-KvdHistory -Path $demoFile -Detailed

Write-Host "`n=== Step 5: Update again ===" -ForegroundColor Green
Set-KvdContent -Path $demoFile -Author "alice" -Message "Add budget section" -Content @"
# Project Alpha

## 目标
开发下一代 AI 辅助工具

## 时间线
- 2026 Q3: 原型开发
- 2026 Q4: 内部测试
- 2027 Q1: 公测发布
- 2027 Q2: 正式上线

## 团队成员
- Alice (PM)
- Bob (Dev)
- Carol (Design)

## 预算
- 开发: 500000
- 基础设施: 200000
- 市场: 150000
"@

Write-Host "`n=== Step 6: Show revision 1 ===" -ForegroundColor Green
Get-KvdCommit -Path $demoFile -Revision 1

Write-Host "`n=== Step 7: Diff rev 1 -> rev 3 ===" -ForegroundColor Green
Compare-KvdCommit -Path $demoFile -FromRevision 1 -ToRevision 3

Write-Host "`n=== Step 8: Verify integrity ===" -ForegroundColor Green
Test-KvdFile -Path $demoFile

Write-Host "`n=== Step 9: Tamper detection ===" -ForegroundColor Green
$tmpFile = [Path]::GetFullPath("$PSScriptRoot/examples/demo-tampered.kvd")
Copy-Item $demoFile $tmpFile -Force
$bad = Get-Content $tmpFile -Raw
$bad = $bad.Replace("开发下一代 AI 辅助工具", "【篡改】旧版 AI")
Set-Content -Path $tmpFile -Value $bad -Encoding utf8
Test-KvdFile -Path $tmpFile
Remove-Item $tmpFile -Force

Write-Host "`nDone! File: $demoFile" -ForegroundColor Green
Write-Host "Try: Get-KvdHistory -Path $demoFile -Detailed"
