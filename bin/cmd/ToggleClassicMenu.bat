@echo off
:: Ensure admin privileges
:init
setlocal DisableDelayedExpansion
set "batchPath=%~0"
for %%k in (%0) do set batchName=%%~nk
set "vbsGetPrivileges=%tmp%\OEgetPriv_%batchName%.vbs"

:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%'=='0' (goto gotPrivileges) else (goto getPrivileges)

:getPrivileges
if '%1'=='ELEV' (shift /1 & goto gotPrivileges)
(
  echo Set UAC = CreateObject^("Shell.Application"^)
  echo args = "ELEV "
  echo For Each strArg in WScript.Arguments
  echo   args = args ^& strArg ^& " "
  echo Next
  echo UAC.ShellExecute "%batchPath%", args, "", "runas", 1
) > "%vbsGetPrivileges%"
"%SystemRoot%\System32\WScript.exe" "%vbsGetPrivileges%" %*
exit /b

:gotPrivileges
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul & shift /1)

set "key=HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
:: Toggle the registry key
reg query "%key%" /ve >nul 2>&1
if %errorlevel%==0 (
    reg delete "%key%" /f >nul
) else (
    reg add "%key%" /f /ve /t REG_SZ /d "" >nul
)
:: Restart explorer to apply changes
taskkill /f /im explorer.exe >nul
start explorer.exe
