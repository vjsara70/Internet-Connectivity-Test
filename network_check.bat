@echo off
:: =========================  CONFIGURATION  =========================
set "LOGFILE=%~dp0Network_Check.log"
set "GATEWAY_IP=61.247.179.9"
set "INTERNET_IP=1.1.1.1"
set "SMS_COMPORT=COM3"              :: <== CHANGE TO YOUR MODEM'S COM PORT
set "SMS_TARGET=+1234567890"        :: <== CHANGE TO THE TARGET MOBILE NUMBER
:: =====================================================================

:: --- helper variables / files ---
set "GATEWAY_FLAG=%~dp0GATEWAY_DOWN.flag"
set "INTERNET_FLAG=%~dp0INTERNET_DOWN.flag"
set "STABLE_FLAG=%~dp0STABLE_COUNT.flag"

:: --- date / time strings (locale-independent) ---
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "DT=%%a"
set "YYYY=%DT:~0,4%"
set "MM=%DT:~4,2%"
set "DD=%DT:~6,2%"
set "HH=%DT:~8,2%"
set "MIN=%DT:~10,2%"
set "NOW=%YYYY%-%MM%-%DD% %HH%:%MIN%"

:: -------------------------------------------------------------
:: 1. Ping tests
:: -------------------------------------------------------------
set "GW_UP=0"
set "INET_UP=0"

ping -n 1 -w 2000 %GATEWAY_IP% >nul && set "GW_UP=1"
ping -n 1 -w 2000 %INTERNET_IP% >nul && set "INET_UP=1"

:: -------------------------------------------------------------
:: 2. Build status strings
:: -------------------------------------------------------------
set "STATUS="
if "%GW_UP%"=="0" set "STATUS=Gateway is Down"
if "%INET_UP%"=="0" (
    if defined STATUS (set "STATUS=%STATUS% and Internet is Down") else (set "STATUS=Internet is Down")
)

:: -------------------------------------------------------------
:: 3. Check if anything is DOWN
:: -------------------------------------------------------------
if "%STATUS%"=="" goto :EVERYTHING_UP

:: --- Something is down ---
echo [%NOW%] ALERT: %STATUS% >> "%LOGFILE%"

:: --- Gateway down flagging ---
if "%GW_UP%"=="0" (
    if not exist "%GATEWAY_FLAG%" (
        echo [%NOW%] Gateway first failure detected >> "%LOGFILE%"
        call :SENDSMS "Gateway (%GATEWAY_IP%) is Down. Date: %NOW%"
        type nul > "%GATEWAY_FLAG%"
    )
) else (
    if exist "%GATEWAY_FLAG%" (
        echo [%NOW%] Gateway back up >> "%LOGFILE%"
        del "%GATEWAY_FLAG%" 2>nul
    )
)

:: --- Internet down flagging ---
if "%INET_UP%"=="0" (
    if not exist "%INTERNET_FLAG%" (
        echo [%NOW%] Internet first failure detected >> "%LOGFILE%"
        call :SENDSMS "Internet (%INTERNET_IP%) is Down. Date: %NOW%"
        type nul > "%INTERNET_FLAG%"
    )
) else (
    if exist "%INTERNET_FLAG%" (
        echo [%NOW%] Internet back up >> "%LOGFILE%"
        del "%INTERNET_FLAG%" 2>nul
    )
)

goto :EOF

:: -------------------------------------------------------------
:: 4. Everything is UP
:: -------------------------------------------------------------
:EVERYTHING_UP
:: If no flags exist we are already stable, just exit
if not exist "%GATEWAY_FLAG%" if not exist "%INTERNET_FLAG%" (
    if exist "%STABLE_FLAG%" del "%STABLE_FLAG%"
    goto :EOF
)

:: At least one flag exists, start counting stable minutes
set /a STABLE=0
if exist "%STABLE_FLAG%" set /p STABLE=<"%STABLE_FLAG%"
set /a STABLE+=1
echo %STABLE% > "%STABLE_FLAG%"
echo [%NOW%] Stable count: %STABLE% >> "%LOGFILE%"

if %STABLE% GEQ 10 (
    echo [%NOW%] Connection stable for 10 minutes >> "%LOGFILE%"
    call :SENDSMS "Connectivity is back and stable. Date: %NOW%"
    del "%GATEWAY_FLAG%" 2>nul
    del "%INTERNET_FLAG%" 2>nul
    del "%STABLE_FLAG%" 2>nul
)
goto :EOF

:: -------------------------------------------------------------
:: 5. Helper: SEND SMS via COM port
:: -------------------------------------------------------------
:SENDSMS
:: %~1 = message body
:: Open COM port, wait 1 s, send AT commands, close port
(
    echo AT^M
    timeout /t 1 >nul
    echo AT+CMGF=1^M
    timeout /t 1 >nul
    echo AT+CMGS="%SMS_TARGET%"^M
    timeout /t 1 >nul
    echo %~1^Z
) >"%SMS_COMPORT%"
echo [%NOW%] SMS sent: "%~1" >> "%LOGFILE%"
goto :EOF
