:: usage: badpings.bat [ip adress | hostname] [ping time threshhold]
 
@echo off
if "%1"=="" (
    set pingdest=10.163.18.52
    ) else (
    set pingdest=%1
    )
 
if "%2"=="" (
    set /a limit=500
    ) else (
    set /a limit=%2
    )
echo Pinging %pingdest%.
echo Logging replies over %limit%ms.
echo Press Ctrl+C to end.
 
:Loop
for /f "usebackq tokens=1-6" %%a in (`ping -n 1 %pingdest% ^| findstr "Request Reply request"`) do (
    set var=%%a %%b %%c %%d %%e %%f
    set pingtimestr=%%e
    )
 
if "%pingtimestr%"=="find" (
    echo Ping request could not find host %pingdest%. Please check the name and try again.
    goto End
    ) 
if "%pingtimestr%"=="host" (
    set /a pingtime=%limit%+1   
    ) 
if "%pingtimestr:~0,4%"=="time" (
    set /a pingtime=%pingtimestr:~5,-2% 
    )
if %pingtime% GTR %limit% (
    echo [%time%] %var%>>badpings.log
    echo [%time%] %var%)
timeout /t 1 /nobreak >nul
Goto Loop
:End 
 
