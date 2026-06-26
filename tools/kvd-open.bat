@echo off
REM KVD File Viewer — double-click a .kvd file to see clean content
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& 'D:\KWD\kvd\tools\kvd-viewer.ps1' '%1'"
