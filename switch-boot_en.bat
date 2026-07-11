@echo off
chcp 936 >nul
setlocal enabledelayedexpansion

:: Get ESC character
for /F "delims=#" %%E in ('"prompt #$E# & for %%E in (1) do rem"') do set "ESC=%%E"

:: Color definitions
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "MAGENTA=%ESC%[95m"      REM Magenta (normal)
set "CYAN=%ESC%[96m"
set "GRAY=%ESC%[90m"
:: Bright red bold (for Ubuntu default option)
set "BOLD_RED=%ESC%[1;91m"

:: ================================================================
:: Manual preset (must fill, used as fallback)
:: ================================================================
set "MANUAL_UBUNTU_ID={xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}"
:: ================================================================

:: Unified cache path
:: set "CACHE_DIR=%ProgramData%\Switch-Boot"
:: set "CACHE_FILE=%CACHE_DIR%\switch-boot.ini"
set "CACHE_DIR=%~dp0"
set "CACHE_FILE=%CACHE_DIR%\switch-boot.ini"
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" 2>nul

:: Administrator check
net session >nul 2>&1
if errorlevel 1 (
    echo %RED%[Error]%RESET% Please run as administrator.
    pause
    exit /b 1
)

:: Attempt to load cache
call :load_ids
if defined WIN_ID if defined UBUNTU_ID goto has_ids

:: Use preset and generate cache
if defined MANUAL_UBUNTU_ID (
    if "%MANUAL_UBUNTU_ID:~0,1%"=="{" (
        set "WIN_ID={bootmgr}"
        set "UBUNTU_ID=%MANUAL_UBUNTU_ID%"
        (
            echo WIN_ID=%WIN_ID%
            echo UBUNTU_ID=%UBUNTU_ID%
        ) > "%CACHE_FILE%" 2>nul
        goto has_ids
    )
)

goto scan

:scan
echo.
echo %CYAN%%BOLD%========================================%RESET%
echo %CYAN%%BOLD%   Scanning UEFI firmware...%RESET%
echo %CYAN%%BOLD%========================================%RESET%

set "TEMP_FILE=%TEMP%\bcd_enum.txt"
bcdedit /enum firmware > "%TEMP_FILE%" 2>nul

set "WIN_ID={bootmgr}"
for /f "tokens=2 delims={}" %%i in ('findstr /i "Windows Boot Manager" "%TEMP_FILE%"') do set "WIN_ID={%%i}"

set "UBUNTU_ID="
for /f "tokens=2 delims={}" %%i in ('findstr /i "Ubuntu" "%TEMP_FILE%"') do set "UBUNTU_ID={%%i}"

if not defined UBUNTU_ID (
    echo %YELLOW%Attempting secondary scan...%RESET%
    set "line_num="
    for /f "delims=:" %%a in ('findstr /n /i "description.*Ubuntu" "%TEMP_FILE%"') do set "line_num=%%a"
    if defined line_num (
        set /a prev=line_num-1
        for /f "tokens=2 delims={}" %%i in ('findstr /n /r ".*" "%TEMP_FILE%" ^| findstr /b "!prev!:"') do set "UBUNTU_ID={%%i}"
    )
)

if not defined UBUNTU_ID (
    echo %YELLOW%Ubuntu identifier not detected automatically, using manual preset.%RESET%
    if defined MANUAL_UBUNTU_ID (
        set "UBUNTU_ID=%MANUAL_UBUNTU_ID%"
    ) else (
        set /p "UBUNTU_ID=Please enter Ubuntu identifier (including braces): "
    )
)

del "%TEMP_FILE%" 2>nul

echo.
echo %GREEN%Detection results:%RESET%
echo   %CYAN%Windows ID:%RESET% %WIN_ID%
echo   %CYAN%Ubuntu  ID:%RESET% %UBUNTU_ID%
echo.
echo %GREEN%Save this configuration for next use? [Y/N]%RESET%
choice /c YN /n /t 10 /d Y
if errorlevel 2 goto skip_save

(
    echo WIN_ID=%WIN_ID%
    echo UBUNTU_ID=%UBUNTU_ID%
) > "%CACHE_FILE%" 2>nul

call :load_ids
if defined WIN_ID if defined UBUNTU_ID (
    echo %GREEN%[Success]%RESET% Cache saved to %BLUE%%CACHE_FILE%%RESET%
) else (
    echo %RED%[Error]%RESET% Cache save failed, please check permissions.
    pause
)

:skip_save
goto has_ids

:has_ids
cls
echo.
echo %CYAN%%BOLD%=============================================%RESET%
echo %CYAN%%BOLD%           Boot Switcher Tool%RESET%
echo %CYAN%%BOLD%=============================================%RESET%
echo.
echo   %YELLOW%Current configuration%RESET%
echo     %GRAY%Windows ID:%RESET% %WIN_ID%
echo     %GRAY%Ubuntu  ID:%RESET% %UBUNTU_ID%
echo     %GRAY%Cache file:%RESET% %BLUE%%CACHE_FILE%%RESET%
echo.
echo %CYAN%%BOLD%=============================================%RESET%
echo %CYAN%%BOLD%   Select system for next boot%RESET%
echo %CYAN%%BOLD%=============================================%RESET%
echo.
echo   %GREEN%1%RESET% - Windows
echo   %BOLD_RED%2 - Ubuntu (default, auto-select after 10s)%RESET%
echo   %GREEN%3%RESET% - UEFI Firmware Settings
echo   %GREEN%r%RESET% - Rescan and update cache
echo   %GREEN%q%RESET% - Cancel
echo.
echo %GRAY%---------------------------------------------%RESET%
echo.

echo %CYAN%Enter your choice:%RESET%
choice /c 123rq /n /t 10 /d 2

if errorlevel 5 goto cancel
if errorlevel 4 goto rescan
if errorlevel 3 goto uefi
if errorlevel 2 goto ubuntu
if errorlevel 1 goto windows

:rescan
del "%CACHE_FILE%" 2>nul
set "WIN_ID="
set "UBUNTU_ID="
goto scan

:windows
echo.
echo %GREEN%Setting next boot to Windows...%RESET%
bcdedit /set {fwbootmgr} bootsequence %WIN_ID%
if errorlevel 1 (
    echo %RED%[Error]%RESET% Set failed.
    pause
    exit /b 1
)
echo %GREEN%[Success]%RESET% System will restart now...
shutdown /r /t 0
goto end

:ubuntu
echo.
echo %GREEN%Setting next boot to Ubuntu...%RESET%
bcdedit /set {fwbootmgr} bootsequence %UBUNTU_ID%
if errorlevel 1 (
    echo %RED%[Error]%RESET% Set failed.
    pause
    exit /b 1
)
echo %GREEN%[Success]%RESET% System will restart now...
shutdown /r /t 0
goto end

:uefi
echo.
echo %GREEN%Rebooting into UEFI firmware settings...%RESET%
shutdown /fw /r /t 0
goto end

:cancel
echo.
echo %YELLOW%Cancelled, system will not restart.%RESET%
:end
pause
exit /b

:load_ids
if not exist "%CACHE_FILE%" exit /b 1
for /f "usebackq tokens=1,* delims==" %%a in ("%CACHE_FILE%") do (
    if "%%a"=="WIN_ID" set "WIN_ID=%%b"
    if "%%a"=="UBUNTU_ID" set "UBUNTU_ID=%%b"
)
if defined WIN_ID if defined UBUNTU_ID (
    if "%WIN_ID:~0,1%"=="{" if "%UBUNTU_ID:~0,1%"=="{" exit /b 0
)
set "WIN_ID="
set "UBUNTU_ID="
exit /b 1
