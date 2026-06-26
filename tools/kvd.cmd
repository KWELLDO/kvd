@echo off
setlocal enabledelayedexpansion

if "%*"=="" goto help

set "KVD_MOD=D:\KWD\kvd\tools\KvdModule.psm1"

REM Short commands
set "C1=%1"
set "REST=%*"
set "REST=!REST:*%1 =!"

if /i "!C1!"=="new"    set "FUNC=New-KvdFile"      & goto exec
if /i "!C1!"=="set"    set "FUNC=Set-KvdContent"   & goto exec
if /i "!C1!"=="get"    set "FUNC=Get-KvdContent"   & goto exec
if /i "!C1!"=="log"    set "FUNC=Get-KvdHistory"   & goto exec
if /i "!C1!"=="rev"    set "FUNC=Get-KvdCommit"    & goto exec
if /i "!C1!"=="diff"   set "FUNC=Compare-KvdCommit" & goto exec
if /i "!C1!"=="check"  set "FUNC=Test-KvdFile"     & goto exec
if /i "!C1!"=="show"   set "FUNC=Show-KvdFile"     & goto exec
if /i "!C1!"=="export" set "FUNC=Export-KvdContent" & goto exec
if /i "!C1!"=="view"   set "FUNC=Show-KvdHistoryView" & goto exec

REM If not a short command, treat C1 as the function name
set "FUNC=!C1!"
set "REST=%*"
set "REST=!REST:*%1 =!"

:exec
pwsh -NoProfile -Command "Import-Module 'D:\KWD\kvd\tools\KvdModule.psm1' -Force; & !FUNC! !REST!"
goto :eof

:help
echo KVD - KWD Versioned Document  (https://github.com/KWELLDO/kvd)
echo.
echo Usage: kvd ^<command^> [arguments...]
echo.
echo Short commands:
echo   kvd new    ^<path^> -Author ^<name^>   -Content ^<text^>
echo   kvd set    ^<path^> -Author ^<name^> -Message ^<msg^> -Content ^<text^>
echo   kvd get    ^<path^>
echo   kvd log    ^<path^> [-Detailed]
echo   kvd rev    ^<path^> -Revision ^<n^>
echo   kvd diff   ^<path^> [-FromRevision ^<n^>] [-ToRevision ^<n^>]
echo   kvd check  ^<path^>
echo   kvd show   ^<path^>
echo   kvd export ^<path^> [-Revision ^<n^>]
echo   kvd view   ^<path^>
echo.
echo Or any PowerShell function directly:
echo   kvd Get-KvdHistory ^<path^> -Detailed
echo.
echo Examples:
echo   kvd new notes.kvd -Author me -Content "第一天笔记"
echo   kvd set notes.kvd -Author me -Message "更新" -Content "第二天笔记"
echo   kvd log notes.kvd -Detailed
echo   kvd check notes.kvd
echo   kvd show notes.kvd
