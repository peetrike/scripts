@echo off
copy "%~dp0set-wallpaper.ps1" %temp%
powershell -ExecutionPolicy remoteSigned -file "%temp%\set-wallpaper.ps1" %*

del "%temp%\set-wallpaper.ps1" /q
