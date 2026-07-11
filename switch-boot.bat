@echo off
chcp 936 >nul
setlocal enabledelayedexpansion

:: 获取 ESC 字符
for /F "delims=#" %%E in ('"prompt #$E# & for %%E in (1) do rem"') do set "ESC=%%E"

:: 颜色定义
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "MAGENTA=%ESC%[95m"      REM 品红（普通）
set "CYAN=%ESC%[96m"
set "GRAY=%ESC%[90m"
:: 亮红色加粗（用于 Ubuntu 默认选项）
set "BOLD_RED=%ESC%[1;91m"

:: ================================================================
:: 手动预设（必须填写，作为备选）
:: ================================================================
set "MANUAL_UBUNTU_ID={46ae5d8d-713a-11f1-91be-806e6f6e6963}"
:: ================================================================

:: 统一缓存路径
:: set "CACHE_DIR=%ProgramData%\Switch-Boot"
:: set "CACHE_FILE=%CACHE_DIR%\switch-boot.ini"
set "CACHE_DIR=%~dp0"
set "CACHE_FILE=%CACHE_DIR%\switch-boot.ini"
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" 2>nul

:: 管理员检查
net session >nul 2>&1
if errorlevel 1 (
    echo %RED%[错误]%RESET% 请以管理员身份运行。
    pause
    exit /b 1
)

:: 尝试加载缓存
call :load_ids
if defined WIN_ID if defined UBUNTU_ID goto has_ids

:: 使用预设值并生成缓存
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
echo %CYAN%%BOLD%   正在扫描 UEFI 固件...%RESET%
echo %CYAN%%BOLD%========================================%RESET%

set "TEMP_FILE=%TEMP%\bcd_enum.txt"
bcdedit /enum firmware > "%TEMP_FILE%" 2>nul

set "WIN_ID={bootmgr}"
for /f "tokens=2 delims={}" %%i in ('findstr /i "Windows Boot Manager" "%TEMP_FILE%"') do set "WIN_ID={%%i}"

set "UBUNTU_ID="
for /f "tokens=2 delims={}" %%i in ('findstr /i "Ubuntu" "%TEMP_FILE%"') do set "UBUNTU_ID={%%i}"

if not defined UBUNTU_ID (
    echo %YELLOW%尝试二次扫描...%RESET%
    set "line_num="
    for /f "delims=:" %%a in ('findstr /n /i "description.*Ubuntu" "%TEMP_FILE%"') do set "line_num=%%a"
    if defined line_num (
        set /a prev=line_num-1
        for /f "tokens=2 delims={}" %%i in ('findstr /n /r ".*" "%TEMP_FILE%" ^| findstr /b "!prev!:"') do set "UBUNTU_ID={%%i}"
    )
)

if not defined UBUNTU_ID (
    echo %YELLOW%未自动检测到 Ubuntu 标识符，将使用手动预设值。%RESET%
    if defined MANUAL_UBUNTU_ID (
        set "UBUNTU_ID=%MANUAL_UBUNTU_ID%"
    ) else (
        set /p "UBUNTU_ID=请输入 Ubuntu 标识符（含大括号）: "
    )
)

del "%TEMP_FILE%" 2>nul

echo.
echo %GREEN%检测结果：%RESET%
echo   %CYAN%Windows ID:%RESET% %WIN_ID%
echo   %CYAN%Ubuntu  ID:%RESET% %UBUNTU_ID%
echo.
echo %GREEN%是否保存此配置（下次直接使用）？[Y/N]%RESET%
choice /c YN /n /t 10 /d Y
if errorlevel 2 goto skip_save

(
    echo WIN_ID=%WIN_ID%
    echo UBUNTU_ID=%UBUNTU_ID%
) > "%CACHE_FILE%" 2>nul

call :load_ids
if defined WIN_ID if defined UBUNTU_ID (
    echo %GREEN%[成功]%RESET% 缓存已保存至 %BLUE%%CACHE_FILE%%RESET%
) else (
    echo %RED%[错误]%RESET% 缓存保存失败，请检查权限。
    pause
)

:skip_save
goto has_ids

:has_ids
cls
echo.
echo %CYAN%%BOLD%=============================================%RESET%
echo %CYAN%%BOLD%           启动切换工具%RESET%
echo %CYAN%%BOLD%=============================================%RESET%
echo.
echo   %YELLOW%当前配置%RESET%
echo     %GRAY%Windows ID:%RESET% %WIN_ID%
echo     %GRAY%Ubuntu  ID:%RESET% %UBUNTU_ID%
echo     %GRAY%缓存文件:%RESET% %BLUE%%CACHE_FILE%%RESET%
echo.
echo %CYAN%%BOLD%=============================================%RESET%
echo %CYAN%%BOLD%   选择下次启动系统%RESET%
echo %CYAN%%BOLD%=============================================%RESET%
echo.
echo   %GREEN%1%RESET% - Windows
echo   %BOLD_RED%2 - Ubuntu（默认，10秒后自动）%RESET%
echo   %GREEN%3%RESET% - UEFI 固件设置
echo   %GREEN%r%RESET% - 重新扫描并更新缓存
echo   %GREEN%q%RESET% - 取消
echo.
echo %GRAY%---------------------------------------------%RESET%
echo.

echo %CYAN%请输入选项：%RESET%
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
echo %GREEN%设置下次启动为 Windows...%RESET%
bcdedit /set {fwbootmgr} bootsequence %WIN_ID%
if errorlevel 1 (
    echo %RED%[错误]%RESET% 设置失败。
    pause
    exit /b 1
)
echo %GREEN%[成功]%RESET% 系统即将重启...
shutdown /r /t 0
goto end

:ubuntu
echo.
echo %GREEN%设置下次启动为 Ubuntu...%RESET%
bcdedit /set {fwbootmgr} bootsequence %UBUNTU_ID%
if errorlevel 1 (
    echo %RED%[错误]%RESET% 设置失败。
    pause
    exit /b 1
)
echo %GREEN%[成功]%RESET% 系统即将重启...
shutdown /r /t 0
goto end

:uefi
echo.
echo %GREEN%正在重启进入 UEFI 固件设置...%RESET%
shutdown /fw /r /t 0
goto end

:cancel
echo.
echo %YELLOW%已取消，系统不会重启。%RESET%
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
