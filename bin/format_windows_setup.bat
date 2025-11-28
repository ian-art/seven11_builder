:startscript
@echo off
set "diskinfo=%~dp0diskinfo64\diskinfo.exe"
set "imagex=%~dp0imagex64\imagex.exe"
if "%sevenzip%" EQU "" SET "sevenzip=%~dp07z64\7z.exe"

cls
echo =========================================================
echo		CREATE WINDOWS INSTALLER * APPLY WIM/ESD
echo =========================================================
echo.
echo.
ECHO 1 = Create a bootable Windows installer
echo 2 = Apply Windows image wim/esd on external or internal drive
echo.
echo.
set "MinValue=1"
set "MaxValue=2"
set "numberchosen="
set /P "numberchosen=What would you like to do? :"
if not defined numberchosen goto startscript
set "numberchosen=%numberchosen:"=%"
if not defined numberchosen goto startscript
for /F delims^=12^ eol^= %%k in ("%numberchosen%") do goto startscript
for /F "tokens=* delims=0" %%k in ("%numberchosen%") do set numberchosen=%%k
if not defined numberchosen set "numberchosen=0"
if "%numberchosen%" GTR "%MaxValue%" goto startscript
IF "%numberchosen%"=="1" goto WINSTALLER
IF "%numberchosen%"=="2" goto WDP

:WINSTALLER
title Windows Bootable USB Creator (UEFI + Legacy Auto)
setlocal enabledelayedexpansion
color 0A
set "usbprep=%temp%\usbprep.txt"
if exist %usbprep% del %usbprep% /f /q >nul

:currentvolumes
cls 
echo =========================================================
echo				WINDOWS BOOTABLE USB CREATOR
echo =========================================================
echo.
echo.
echo Detecting current firmware type...
call :FIRMWARETYPE
echo.
set /p "use_recommended=Use recommended layout for %detected_machine%? (Y/N): "
if /i "%use_recommended%"=="Y" (
    set "usegpt=%detected_style%"
	for /f "skip=2 delims=" %%I in ('tree "\%use_recommended%"') do if not defined upper set upper=%%~I
	set use_recommended=%upper:~3%
	set upper=
) else if /i "%use_recommended%"=="N" (
	IF "%detected_style%"=="GPT" SET "usegpt=MBR"
	IF "%detected_style%"=="MBR" SET "usegpt=GPT"
	for /f "skip=2 delims=" %%I in ('tree "\%use_recommended%"') do if not defined upper set upper=%%~I
	set use_recommended=%upper:~3%
	set upper=
)

REM ------------------------------------------
REM List current volumes for safety
REM ------------------------------------------
ECHO.
echo Listing available volumes...
echo.
call :diskpartlists
echo.
set /p usbvol=Enter the USB volume letter [e.g. e]:
if "%usbvol%" EQU "" goto currentvolumes
SET "usbvol=%usbvol:~0,1%:"
vol %usbvol% >nul 2>nul || (
echo    Drive %usbvol% does not exist, please input again.
echo.
	set usbvol= 
	pause>nul
	goto currentvolumes
)
for /f "skip=2 delims=" %%I in ('tree "\%usbvol%"') do if not defined upper set upper=%%~I
set usbvol=%upper:~3%
set upper=
if "%usbvol%" equ "" goto currentvolumes

:winisopath
FOR /F "tokens=*" %%I IN ('%diskinfo% -DiskNumber %usbvol%') DO SET "DiskNumber=%%I"
cls
echo =========================================================
echo				WINDOWS BOOTABLE USB CREATOR
echo =========================================================
REM ------------------------------------------
REM Ask for Windows ISO
REM -----------------------------------------
echo.
echo.
set /p isopath=Enter full path to Windows ISO :
if not exist "%isopath%" (
    echo ERROR: ISO not found.
    pause
    goto winisopath
)

cls
echo =========================================================
echo				WINDOWS BOOTABLE USB CREATOR
echo =========================================================
echo.
echo.
echo Kindly review before you proceed.
echo.
ECHO SELECTED PARTITION STYLE	: %usegpt%
ECHO SELECTED DRIVE			: %usbvol%
echo ISO PATH			: %isopath%
ECHO.
echo.
rem remind user if chose gpt while local machine is legacy bios
IF /I "%detected_machine%" EQU "LEGACY BIOS" (
IF /I "%usegpt%" NEQ "MBR" (
echo NOTE: YOUR %detected_machine% MACHINE WONT BE ABLE TO RECOGNIZE YOUR SELECTED PARTITION STYLE.
	)
)
echo.
pause
cls
echo =========================================================
echo				WINDOWS BOOTABLE USB CREATOR
echo =========================================================
ECHO.
echo.
REM ------------------------------------------
REM If UEFI (GPT) – create 2 partitions
REM ------------------------------------------
if /i "%usegpt%"=="GPT" (
		echo select volume %usbvol% >> "%usbprep%"
		echo clean >> "%usbprep%"
		echo convert gpt >> "%usbprep%"
		echo create partition primary size=64 >> "%usbprep%"
		echo select partition 1 >> "%usbprep%"
		echo format fs=fat32 quick >> "%usbprep%"
		echo set id="c12a7328-f81f-11d2-ba4b-00a0c93ec93b" >> "%usbprep%"
		echo assign letter=V >> "%usbprep%"
		echo create partition primary >> "%usbprep%"
		echo select partition 2 >> "%usbprep%"
		echo format fs=ntfs quick >> "%usbprep%"
		echo assign letter=W >> "%usbprep%"
		echo exit >> "%usbprep%"
	) else (
REM ------------------------------------------
REM If Legacy (MBR) – single NTFS partition
REM ------------------------------------------
        echo select volume %usbvol% >> "%usbprep%"
        echo clean >> "%usbprep%"
        echo convert mbr >> "%usbprep%"
        echo create partition primary >> "%usbprep%"
        echo active >> "%usbprep%"
        echo format fs=ntfs quick >> "%usbprep%"
        echo assign letter=%usbvol% >> "%usbprep%"
        echo exit >> "%usbprep%"
)

REM Run diskpart
echo Running DiskPart to prepare drive...
diskpart /s "%usbprep%"
if %errorlevel% neq 0 (
    echo DiskPart failed. Exiting.
    pause
    exit /b
)
del "%usbprep%" >nul 2>&1
set usbprep=

REM ------------------------------------------
REM If GPT (UEFI)
REM ------------------------------------------
if /i "%usegpt%"=="GPT" (
    echo.
    echo Extracting ISO.. please wait...
    "%sevenzip%" x "%isopath%" -o"W:\" -y >nul
    if %errorlevel% neq 0 (
        echo Extraction failed!
        pause
        exit /b
    )

    echo.
    echo Doing extra work... please wait...
	xcopy "%~dp0win11\*" "V:\" /E /I /H /Y >nul
) else (
REM ------------------------------------------
REM If Legacy (MBR)
REM ------------------------------------------
    echo.
    echo Extracting ISO to NTFS partition %usbvol%.
    "%sevenzip%" x "%isopath%" -o"%usbvol%\" -y >nul
    if %errorlevel% neq 0 (
        echo Extraction failed!
        pause
        exit /b
    )
	echo.
    echo Doing extra work... please wait...
	xcopy "%~dp0win11\*" "V:\" /E /I /H /Y >nul
)

cls
echo =========================================================
echo			BOOTABLE USB CREATION COMPLETE!
echo =========================================================
echo.
echo.
if /i "%usegpt%"=="GPT" (
    echo Partition 1 [FAT32]	: EFI/UEFI boot files
    echo Partition 2 [NTFS]	:  Windows setup files
) else (
    echo Partition 1 [NTFS]	: BIOS/Legacy boot files
)
echo.
endlocal
pause
exit /b

rem ##################################################################################################
REM ##################################################################################################
rem ##################################################################################################

:WDP
cls 
title Windows Disk Prep + Apply WIM
color 0A
setlocal enabledelayedexpansion

if exist "%tmp%\wimesdisoinfo.txt" del "%tmp%\wimesdisoinfo.txt" /f /q >nul
if exist "%tmp%\ImageInfo.txt" del "%tmp%\ImageInfo.txt" /f /q >nul

REM --- Helper: require elevation check ---
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator.
    pause
    exit /b
)

REM =====================================================
REM  SECTION 1: GATHER ALL USER INPUTS
REM =====================================================
:driveselect
cls 
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
call :diskpartlists
echo.
REM --- Ask for target drive letter (where Windows will be applied) ---
set /p drv=Enter the target drive letter [ENTER=REFRESH]:
if "%drv%" EQU "" goto driveselect
SET "drv=%drv:~0,1%:"
vol %drv% >nul 2>nul || (
echo    Drive %drv% does not exist, please input again.
echo.
	set drv= 
	pause>nul
	goto driveselect
)
for /f "skip=2 delims=" %%I in ('tree "\%drv%"') do if not defined upper set upper=%%~I
set drv=%upper:~3%
set upper=
if "%drv%" equ "" goto driveselect

:normtogo
cls
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
REM --- Ask if Windows To Go or Normal install ---
set /p istogo=Is this for Windows To Go? (Y/N): 
if /i "%istogo%"=="Y" (
    set "layout_choice=TOGO"
) else if /i "%istogo%"=="N" (
    set "layout_choice=NORMAL"
) else (
    echo Invalid choice. Please type Y or N.
    pause>nul
    goto normtogo
)
for /f "skip=2 delims=" %%I in ('tree "\%istogo%"') do if not defined upper set upper=%%~I
set istogo=%upper:~3%
set upper=

:partitionstyle
cls
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
REM --- Detect firmware using bcdedit (your method) ---
echo.
call :FIRMWARETYPE
echo.
echo.
echo SELECTED DRIVE PARTITION SCHEME
FOR /F "tokens=*" %%I IN ('%diskinfo% -PartitionSchm %drv%') DO SET "PartitionSchm=%%I"
FOR /F "tokens=*" %%i IN ('%diskinfo% -DiskNumber %drv%') DO SET "diskid=%%i"
echo.
echo Drive %drv% Disk #			: %diskid%
echo Current partition style		: %PartitionSchm%
echo.
REM Ask user whether to use recommended style for this firmware
echo.
set /p "use_recommended=Use recommended layout for %detected_machine%? (Y/N): "
if /i "%use_recommended%"=="Y" (
    set "usegpt=%detected_style%"
	for /f "skip=2 delims=" %%I in ('tree "\%use_recommended%"') do if not defined upper set upper=%%~I
	set use_recommended=%upper:~3%
	set upper=
	goto ask_target_type
) else if /i "%use_recommended%"=="N" (
    set usegpt=
) ELSE (
	GOTO partitionstyle
)

:gptormbr
cls
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
REM --- Manual selection loop ---
set /p "usegpt=Choose partition style manually [GPT/MBR]: "
if /i "%usegpt%"=="GPT" (
    set "usegpt=GPT"
) else (
    if /i "%usegpt%"=="MBR" (
        set "usegpt=MBR"
    ) else (
        echo Invalid choice. Please type GPT or MBR.
		pause >nul
        goto gptormbr
    )
)
echo.
if "%usegpt%" equ "" goto gptormbr
for /f "skip=2 delims=" %%I in ('tree "\%usegpt%"') do if not defined upper set upper=%%~I
set usegpt=%upper:~3%
set upper=
echo Final partition style to use: %usegpt%
timeout 3 /nobreak >nul

REM --- Ask user for the INTENDED drive use ---
:ask_target_type
cls
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
echo What is the INTENDED use for this drive?
echo.
echo   [I] - An INTERNAL drive for a standard PC (Uses MS-Recommended layout)
echo   [E] - An EXTERNAL/Removable drive (Uses Rufus-style layout)
echo.
set /p "install_type=Enter [I] or [E]: "
if /i "%install_type%"=="I" (
    set target_type=Internal
    set style=Microsoft
) else if /i "%install_type%"=="E" (
    set target_type=External
    set style=Rufus
) else (
    echo Invalid choice. Please press I or E.
    goto ask_target_type
)
for /f "skip=2 delims=" %%I in ('tree "\%install_type%"') do if not defined upper set upper=%%~I
set install_type=%upper:~3%
set upper=
if "%target_type%" equ "" goto ask_target_type

:imagepath
cls
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
REM --- Ask for WIM/ESD path and image index ---
echo.
set /p wimpath=Enter full path to .wim or .esd: 
if exist "%wimpath%\" (
    echo You entered a folder, not a file.
    pause >nul
    goto imagepath
)
if "%wimpath%"==" " (
    echo No image path provided.
	pause >nul
	goto imagepath
)
if not exist "%wimpath%" (
    echo File not found.
    pause >nul
    goto imagepath
)

:askindex
cls
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
if exist "%ImageInfo%" del "%ImageInfo%" /f /q >nul
if exist "%wimesdisoinfo%" del "%wimesdisoinfo%" /f /q >nul
"%imagex%" /info "%wimpath%" >"%tmp%\wimesdisoinfo.txt"
set "wimesdisoinfo=%tmp%\wimesdisoinfo.txt"
set "ImageInfo=%tmp%\ImageInfo.txt"
for /f "tokens=1,2 delims=:" %%u in (%wimesdisoinfo%) do IF /I "%%u"=="Image Count" set ic=%%v
echo Total image number:%ic%
echo.
if %ic% equ 1 (
echo Available image:
) else (
echo Available images:
)
echo.
echo. INDEX    ARCHITECTURE    IMAGE NAME
for /f "tokens=2 delims=: " %%a in ('dism /Get-WimInfo /WimFile:"%wimpath%" ^| findstr /i Index') do (
	for /f "tokens=2 delims=: " %%b in ('dism /Get-WimInfo /WimFile:"%wimpath%" /Index:%%a ^| findstr /i Architecture') do (
		for /f "tokens=2 delims=:" %%c in ('dism /Get-WimInfo /WimFile:"%wimpath%" /Index:%%a ^| findstr /i Name') do (
			if "%%b" neq "arm64" (
				if %%a leq 9 echo. %%a        %%b            %%c >>%ImageInfo%
				if %%a gtr 9 if %%a lss 99 echo. %%a        %%b            %%c >>%ImageInfo%
				if %%a gtr 99 echo. %%a        %%b            %%c >>%ImageInfo%
			)			
			if "%%b" equ "arm64" (
				if %%a leq 9 echo. %%a        %%b            %%c >>%ImageInfo%
				if %%a gtr 9 if %%a lss 99 echo. %%a        %%b            %%c >>%ImageInfo%
				if %%a gtr 99 echo. %%a        %%b            %%c >>%ImageInfo%
			)
		)
	)
)
type "%ImageInfo%"

:indexnumber
echo.
set "windex="
set /p windex=Enter IMAGE INDEX number: 
if "%windex%"=="" goto askindex
set "windex=%windex:~0,3%"

rem === trim any spaces ===
for /f "tokens=* delims= " %%I in ("%windex%") do set "windex=%%I"

rem === Validate index directly using imagex ===
"%imagex%" /info "%wimpath%" %windex% >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo    INDEX NUMBER is wrong, please input a correct number.
    goto askindex
)

if exist "%ImageInfo%" del "%ImageInfo%" /f /q >nul
if exist "%wimesdisoinfo%" del "%wimesdisoinfo%" /f /q >nul

SET "Wimesdindex=%windex%"
set "ImageInfo2=%tmp%\ImageInfo2.txt"
for /f "tokens=2 delims=: " %%o in ('dism.exe /Get-WimInfo /WimFile:"%wimpath%" /Index:%windex% ^| findstr /i Architecture') do (
			if "%%o" neq "arm64" (
				if %windex% leq 9 echo. %%o>>%ImageInfo2%
				if %windex% gtr 9 if %windex% lss 99 echo. %%o>>%ImageInfo2%
				if %windex% gtr 99 echo. %%o>>%ImageInfo2%
			)			
			if "%%o" equ "arm64" (
				if %windex% leq 9 echo. %%o>>%ImageInfo2%
				if %windex% gtr 9 if %windex% lss 99 echo. %%o>>%ImageInfo2%
				if %windex% gtr 99 echo. %%o>>%ImageInfo2%
		)
	)

FIND /C /I "x86" %ImageInfo2% >nul 2>&1
if errorlevel 1 (
set arch=x64
) else (
set arch=x86
)
for /f "tokens=2 delims=:" %%a in ('dism.exe /Get-WimInfo /WimFile:"%wimpath%" /Index:%windex% ^| findstr /i Name') do (set ImageName=%%a)

set "ImageName=%ImageName:~1%"
if exist "%ImageInfo2%" del "%ImageInfo2%" /f /q >nul

:final
cls
REM --- Confirm again before writing diskpart script ---
echo =====================================================
echo       Windows Disk Prep + Apply WIM (Auto bcdboot)
echo =====================================================
echo.
echo.
echo Kindly review before you proceed.
echo.
echo TARGET DRIVE		:	%drv% [disk %diskid%]
ECHO INSTALLLATION TYPE	:	%layout_choice%
ECHO PARTITION STYLE		:	%usegpt%
echo INSTALL WINDOWS		:	%target_type% [%style% layout]
ECHO WIM/ESD FULL PATH	:	%wimpath%
echo INDEX NUMBER		:	%Wimesdindex% [%ImageName%] [%arch%]
echo.
echo.
set /p decide=press enter to continue... or x to close. :
if "%decide%"=="" goto PROCESS
for /f "skip=2 delims=" %%I in ('tree "\%decide%"') do if not defined upper set upper=%%~I
set decide=%upper:~3%
set upper=
if "%decide%" EQU "X" goto end
if "%decide%" NEQ "" goto final

:PROCESS
cls
REM =====================================================
REM  SECTION 2: PROCESS EVERYTHING
REM =====================================================

FOR /F "tokens=*" %%I IN ('%diskinfo% -DiskCapG %drv%') DO (
    SET "DiskCap=%%I"
)

REM --- Prepare diskpart script ---
set "dpscript=%temp%\_diskpart_%diskid%.txt"
if exist "%dpscript%" del "%dpscript%" /f /q >nul 2>&1

rem valid in live Windows, dunno in winpe
echo select volume %drv% >> "%dpscript%"
echo clean >> "%dpscript%"

REM echo select volume %drv% >> "%dpscript%"
REM echo clean >> "%dpscript%"
REM echo if errorlevel 1 select disk %diskid% >> "%dpscript%"
REM echo if errorlevel 1 clean >> "%dpscript%"

if /i "%usegpt%"=="GPT" (
    echo convert gpt >> "%dpscript%"
) else (
    echo convert mbr >> "%dpscript%"
)

set rexist=0

REM --- Build partitions based on rules ---
if /i "%target_type%"=="External" (
    if /i "%layout_choice%"=="TOGO" (
        REM === External + ToGo -> Single NTFS Partition (Windows To Go style) ===
        echo create partition primary >> "%dpscript%"
        echo format quick fs=ntfs label="WindowsToGo" >> "%dpscript%"
        echo assign letter=%drv% >> "%dpscript%"
        if /i "%usegpt%"=="MBR" echo active >> "%dpscript%"
        echo exit >> "%dpscript%"

        if /i "%usegpt%"=="GPT" (
            for %%U in ("%drv%\Windows /s %drv% /f UEFI") do set "bcdexecute=%%~U"
        ) else (
            for %%U in ("%drv%\Windows /s %drv% /f BIOS") do set "bcdexecute=%%~U"
        )

    ) else (
        REM === External + Normal Installation ===
        if /i "%usegpt%"=="GPT" (
            REM --- GPT Layout: EFI + Windows ---
            echo create partition efi size=100 >> "%dpscript%"
            echo format quick fs=fat32 label="System" >> "%dpscript%"
            echo assign letter=S >> "%dpscript%"
            echo create partition primary >> "%dpscript%"
            echo format quick fs=ntfs label="Windows" >> "%dpscript%"
            echo assign letter=%drv% >> "%dpscript%"
            echo exit >> "%dpscript%"

            for %%U in ("%drv%\Windows /s S: /f UEFI") do set "bcdexecute=%%~U"
            set targetis=UEFI
        ) else (
            REM --- MBR Layout: System + Windows ---
            echo create partition primary size=500 >> "%dpscript%"
            echo format quick fs=ntfs label="System" >> "%dpscript%"
            echo active >> "%dpscript%"
            echo assign letter=S >> "%dpscript%"
            echo create partition primary >> "%dpscript%"
            echo format quick fs=ntfs label="Windows" >> "%dpscript%"
            echo assign letter=%drv% >> "%dpscript%"
            echo exit >> "%dpscript%"

            for %%U in ("%drv%\Windows /s S: /f BIOS") do set "bcdexecute=%%~U"
            set targetis=BIOS
        )
    )
) else (
    REM INTERNAL disk -> Microsoft recommended
    if /i "%usegpt%"=="GPT" (
	set rexist=
		echo create partition primary size=450 >> "%dpscript%"
		echo format quick fs=ntfs label="WinRE tools" >> "%dpscript%"
		echo set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac" >> "%dpscript%"
		echo assign letter=T >> "%dpscript%"
		echo create partition efi size=260 >> "%dpscript%"
		echo format quick fs=fat32 label="System" >> "%dpscript%"
		echo assign letter=S >> "%dpscript%"
		echo create partition msr size=128 >> "%dpscript%"
		echo create partition primary >> "%dpscript%"
		
		if %DiskCap% GEQ 256 (
		echo shrink minimum=15000 >> "%dpscript%"
		echo format quick fs=ntfs label="Windows" >> "%dpscript%"
		echo assign letter=%drv% >> "%dpscript%"
		echo create partition primary >> "%dpscript%"
		echo format quick fs=ntfs label="Recovery image" >> "%dpscript%"
		echo assign letter=R >> "%dpscript%"
		echo list volume >> "%dpscript%"
		echo exit >> "%dpscript%"
		for %%U in ("%drv%\Windows /s S: /f UEFI") do set "bcdexecute=%%~U"
		set rexist=1
		) ELSE (
		echo format quick fs=ntfs label="Windows" >> "%dpscript%"
		echo assign letter=%drv% >> "%dpscript%"
		echo list volume >> "%dpscript%"
		echo exit >> "%dpscript%"
		for %%U in ("%drv%\Windows /s S: /f UEFI") do set "bcdexecute=%%~U"
		)
    ) else (
		set rexist=	
		echo create partition primary size=500 >> "%dpscript%"
		echo format quick fs=ntfs label="System Reserved" >> "%dpscript%"
		echo active >> "%dpscript%"
		echo assign letter=S >> "%dpscript%"
		echo create partition primary >> "%dpscript%"

		if %DiskCap% GEQ 232 (
		echo shrink minimum=15000 >> "%dpscript%"
		echo format quick fs=ntfs label="Windows" >> "%dpscript%"
		echo assign letter=%drv% >> "%dpscript%"
		echo create partition primary >> "%dpscript%"
		echo format quick fs=ntfs label="Recovery image" >> "%dpscript%"
		echo assign letter=R >> "%dpscript%"
		echo list volume >> "%dpscript%"
		echo exit >> "%dpscript%"
		for %%U in ("%drv%\Windows /s S: /f BIOS") do set "bcdexecute=%%~U"
		set rexist=1
		) ELSE (
		echo format quick fs=ntfs label="Windows" >> "%dpscript%"
		echo assign letter=%drv% >> "%dpscript%"
		echo list volume >> "%dpscript%"
		echo exit >> "%dpscript%"
		for %%U in ("%drv%\Windows /s S: /f BIOS") do set "bcdexecute=%%~U"
		)
	)
)
REM --- Run diskpart ---
echo.
echo Running DiskPart to apply partition layout...
diskpart /s "%dpscript%"
del "%dpscript%" /f /q >nul 2>&1
if %errorlevel% neq 0 (
    echo DiskPart failed. Aborting.
    pause
    exit /b
)

REM Ensure target drive letter root exists.
echo.
if not exist %drv%\ (
    echo Target drive %drv% not present after partitioning. Aborting.
    pause
    exit /b
)

REM --- Apply image using DISM ---
echo.
echo Applying image. This can take a long time...
dism.exe /Apply-Image /ImageFile:"%wimpath%" /Index:%windex% /ApplyDir:%drv%
if %errorlevel% neq 0 (
    echo DISM failed. Aborting.
    pause
    exit /b
)

REM --- Run bcdboot to create boot files ---
echo Running bcdboot to create boot files...

bcdboot.exe %bcdexecute%
if errorlevel 1 (
    echo [ERROR] bcdboot failed! Keeping drive letter S: for manual repair.
	echo.
	pause
	exit /b
)

REM --- Apply Windows To Go setup if selected ---
if /i "%layout_choice%"=="TOGO" (
    echo.
    echo Applying Windows To Go configuration...

    if /i "%usegpt%"=="MBR" (
        REM MBR/BIOS: Use bootsect to update MBR boot code
        bootsect.exe /nt60 %drv% /mbr /force
    )

    REM Enable PortableOperatingSystem launcher
    reg load HKLM\_software "%drv%\Windows\System32\config\SOFTWARE" >nul 2>&1
    if %errorlevel%==0 (
        timeout /t 1 /nobreak >nul
        reg add "HKLM\_software\Policies\Microsoft\PortableOperatingSystem" /v "Launcher" /t REG_DWORD /d 0 /f >nul 2>&1
        reg unload HKLM\_software >nul 2>&1
        echo Windows To Go policy applied successfully.
    ) else (
        echo [Warning] Failed to load registry hive from %drv%.
    )
)

REM --- Handle temporary EFI/Boot partition letters ---
for %%L in (S) do (
    if exist %%L:\EFI (
        if /i "%usegpt%"=="GPT" (
            REM Temporary EFI partition, remove letter
            echo Removing drive letter %%L: ...
            >"%temp%\removeS.txt" echo select volume %%L
            >>"%temp%\removeS.txt" echo remove letter=%%L
			if "%rexist%"=="1" (
            >"%temp%\removeS.txt" echo select volume R
            >>"%temp%\removeS.txt" echo remove letter=R
			)
            diskpart /s "%temp%\removeS.txt" >nul
            del "%temp%\removeS.txt" >nul 2>&1
        )
    ) else if exist %%L:\Boot (
        if /i "%usegpt%"=="MBR" (
            REM BIOS boot partition: update boot code and remove letter
            bootsect.exe /nt60 %%L: /mbr /force
            echo Removing drive letter %%L: ...
            timeout /t 1 /nobreak >nul
            >"%temp%\removeS.txt" echo select volume %%L
            >>"%temp%\removeS.txt" echo remove letter=%%L
			if "%rexist%"=="1" (
            >"%temp%\removeS.txt" echo select volume R
            >>"%temp%\removeS.txt" echo remove letter=R
			)
            diskpart /s "%temp%\removeS.txt" >nul
            del "%temp%\removeS.txt" >nul 2>&1
        )
    )
)

set bcdexecute=

echo.
echo =====================================================
echo Completed: Image applied and boot files created.
echo =====================================================
echo.
echo.
echo Windows installation is complete. The system is now ready to boot.
echo.
echo.
pause
:end
endlocal
exit /b

rem ##################################################################################################
REM ##################################################################################################
rem ##################################################################################################

:FIRMWARETYPE
echo CURRENT FIRMWARE TYPE
for /f "tokens=2 delims==" %%A in ('bcdedit /enum {current} ^| find "path"') do set "bootmode=%%A"
echo %bootmode% | find /i ".efi" >nul && (
    set "detected_machine=UEFI"
    set "detected_style=GPT"
) || (
    set "detected_machine=LEGACY BIOS"
    set "detected_style=MBR"
)
echo.
echo Detected boot mode		: %detected_machine%
echo Recommended partition style	: %detected_style%
goto :eof

:diskpartlists
echo Do not choose Drive C:
echo.
echo list volume | diskpart | findstr /C:Volume /C:---
goto :eof