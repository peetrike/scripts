@echo off
copy "%~dp0copy-wallpaper.ps1" %temp%
powershell -ExecutionPolicy remoteSigned -file "%temp%\copy-wallpaper.ps1" %~dp0 %*

del "%temp%\copy-wallpaper.ps1" /q
